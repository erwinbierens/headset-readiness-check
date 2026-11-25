Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='Esprit ICT Bluetooth Check | Windows 11'
$form.Size=New-Object Drawing.Size(1220,820)
$form.MinimumSize=New-Object Drawing.Size(960,650)
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$form.BackColor=[Drawing.Color]::FromArgb(245,247,251)
$top=New-Object Windows.Forms.Panel
$top.Dock='Top';$top.Height=210;$top.BackColor=[Drawing.Color]::White
$assetRoot=if(Test-Path (Join-Path $PSScriptRoot 'esprit-ict-logo.png')){$PSScriptRoot}else{Join-Path $PSScriptRoot '..\assets'}
$logo=New-Object Windows.Forms.PictureBox
$logo.Image=[Drawing.Image]::FromFile((Join-Path $assetRoot 'esprit-ict-logo.png'))
$logo.SizeMode='Zoom';$logo.SetBounds(23,16,235,52)
$form.Icon=New-Object Drawing.Icon((Join-Path $assetRoot 'esprit-ict.ico'))
$title=New-Object Windows.Forms.Label
$title.Text='Bluetooth Check';$title.Font=New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold)
$title.SetBounds(280,17,650,42)
$subtitle=New-Object Windows.Forms.Label
$subtitle.Text='Classic Bluetooth en LE Audio | Alleen uitlezen | Regels gecontroleerd op 23 november 2026'
$subtitle.SetBounds(23,80,1100,24)
$variantLabel=New-Object Windows.Forms.Label;$variantLabel.Text='Kies de te controleren variant:';$variantLabel.SetBounds(23,119,230,25)
$variant=New-Object Windows.Forms.ComboBox;$variant.DropDownStyle='DropDownList';$variant.SetBounds(260,115,420,32)
[void]$variant.Items.Add('Native Bluetooth Classic (A2DP / HFP)')
[void]$variant.Items.Add('Bluetooth LE Audio (LE Audio / TMAP)')
$variant.SelectedIndex=0
$scan=New-Object Windows.Forms.Button;$scan.Text='Controle starten';$scan.SetBounds(23,160,160,36);$scan.BackColor=[Drawing.Color]::FromArgb(255,130,0);$scan.FlatStyle='Flat'
$export=New-Object Windows.Forms.Button;$export.Text='Rapport opslaan';$export.SetBounds(195,160,160,36);$export.Enabled=$false
$state=New-Object Windows.Forms.Label;$state.Text='Start een controle. De app wijzigt geen drivers of instellingen.';$state.SetBounds(375,163,800,38)
$top.Controls.AddRange(@($logo,$title,$subtitle,$variantLabel,$variant,$scan,$export,$state))
$variant.Add_SelectedIndexChanged({$script:report=$null;$grid.Rows.Clear();$export.Enabled=$false;$state.Text='Variant gewijzigd. Start een nieuwe controle.';$detail.Text=if($variant.SelectedIndex -eq 0){'Classic: controle van de native Windows-verbinding met A2DP/HFP. LE Audio-specifieke controles zijn voor deze variant niet van toepassing.'}else{'LE Audio: controle van de Windows-basis plus de aanvullende LE Audio/OEM-codec-voorwaarden. LE Audio, actieve route en exacte Dual Mode-certificering vereisen aanvullende bevestiging.'}})
$bottom=New-Object Windows.Forms.FlowLayoutPanel;$bottom.Dock='Bottom';$bottom.Height=52;$bottom.Padding=New-Object Windows.Forms.Padding(15,6,0,0)
foreach($entry in @(@('Bluetooth','ms-settings:bluetooth'),@('Geluid','ms-settings:sound'),@('Microfoontoegang','ms-settings:privacy-microphone'),@('Windows Update','ms-settings:windowsupdate'),@('Apparaatbeheer','devmgmt.msc'),@('Microsoft-voorwaarden','https://learn.microsoft.com/en-us/microsoftteams/devices/bluetooth-devices'))){
 $b=New-Object Windows.Forms.Button;$b.Text=$entry[0];$b.AutoSize=$true;$b.Height=32;$b.Tag=$entry[1]
 $b.Add_Click({try{Start-Process $this.Tag}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message)}})
 $bottom.Controls.Add($b)
}
$split=New-Object Windows.Forms.SplitContainer;$split.Dock='Fill';$split.Orientation='Horizontal';$split.Size=New-Object Drawing.Size(1160,560);$split.SplitterDistance=320
$grid=New-Object Windows.Forms.DataGridView;$grid.Dock='Fill';$grid.ReadOnly=$true;$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false;$grid.RowHeadersVisible=$false;$grid.SelectionMode='FullRowSelect';$grid.MultiSelect=$false;$grid.AutoSizeColumnsMode='Fill';$grid.BackgroundColor=[Drawing.Color]::White
foreach($col in @('Status','Onderdeel','Controle','Bewijs')){[void]$grid.Columns.Add($col,$col)}
$grid.Columns[0].FillWeight=14;$grid.Columns[1].FillWeight=18;$grid.Columns[2].FillWeight=32;$grid.Columns[3].FillWeight=55
$detail=New-Object Windows.Forms.TextBox;$detail.Dock='Fill';$detail.Multiline=$true;$detail.ReadOnly=$true;$detail.ScrollBars='Vertical';$detail.BackColor=[Drawing.Color]::White;$detail.Font=New-Object Drawing.Font('Segoe UI',11)
$detail.Text="Selecteer na het scannen een controle voor bewijs en hersteladvies.`r`n`r`nOK = deze controle slaagt. Handmatig/Onbekend = nog niet bewezen. Advies = aanbevolen verbetering. Probleem = aangetroffen blokkade.`r`n`r`nEen groene deelcontrole bewijst nooit op zichzelf dat de complete Teams-audioketen geschikt is."
$split.Panel1.Controls.Add($grid);$split.Panel2.Controls.Add($detail)
$form.Controls.Add($split);$form.Controls.Add($bottom);$form.Controls.Add($top)
$script:report=$null;$script:worker=$null;$script:output=$null
$grid.Add_SelectionChanged({if($grid.SelectedRows.Count -and $script:report){$c=$script:report.Checks[$grid.SelectedRows[0].Index];$detail.Text="$($c.Name) [$($c.Status)]`r`n`r`nBEWIJS`r`n$($c.Evidence)`r`n`r`nADVIES / VERVOLG`r`n$($c.Advice)"}})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=500
$timer.Add_Tick({
 if($script:worker -and $script:worker.HasExited){
  $timer.Stop();$scan.Enabled=$true;$variant.Enabled=$true
  try{
   if($script:worker.ExitCode -ne 0 -or !(Test-Path -LiteralPath $script:output)){throw 'Verzameling mislukt. Controleer of Windows PowerShell, CIM en PnP zijn toegestaan door het organisatiebeleid.'}
   $script:report=Get-Content -LiteralPath $script:output -Raw | ConvertFrom-Json
   $grid.Rows.Clear()
   foreach($c in $script:report.Checks){$i=$grid.Rows.Add($c.Status,$c.Area,$c.Name,($c.Evidence -replace '[\r\n]+',' | '));$grid.Rows[$i].DefaultCellStyle.BackColor=switch($c.Status){'OK'{[Drawing.Color]::FromArgb(229,245,235)}'Probleem'{[Drawing.Color]::FromArgb(255,224,224)}'Advies'{[Drawing.Color]::FromArgb(255,242,208)}default{[Drawing.Color]::White}}}
   $export.Enabled=$true
   $count=@($script:report.Checks | Where-Object Status -eq 'Probleem').Count
   $pending=@($script:report.Checks | Where-Object {$_.Status -in @('Handmatig','Onbekend')}).Count
   $state.Text="$count problemen | $pending controles open | Geen volledige geschiktheidsverklaring"
   $detail.Text=$script:report.Verdict+"`r`n`r`nSelecteer een rij voor bewijs en hersteladvies."
  }catch{$state.Text='Controle mislukt';[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Controle mislukt')}
  finally{Remove-Item -LiteralPath $script:output -Force -ErrorAction SilentlyContinue;$script:worker.Dispose();$script:worker=$null}
 }
})
$scan.Add_Click({
 $scan.Enabled=$false;$variant.Enabled=$false;$export.Enabled=$false;$state.Text='Windows, apparaten, drivers en Teams worden uitgelezen...'
 $script:output=Join-Path $env:TEMP (([guid]::NewGuid().ToString('N'))+'.json')
 $p=New-Object Diagnostics.ProcessStartInfo
 $p.FileName=Join-Path $PSHOME 'powershell.exe'
 $selectedVariant=if($variant.SelectedIndex -eq 0){'Classic'}else{'LEAudio'}
 $p.Arguments='-NoProfile -NonInteractive -File "'+(Join-Path $PSScriptRoot 'Collect.ps1')+'" -OutputPath "'+$script:output+'" -Variant '+$selectedVariant
 $p.UseShellExecute=$false;$p.CreateNoWindow=$true
 try{$script:worker=[Diagnostics.Process]::Start($p);$script:started=Get-Date;$timer.Start()}catch{$scan.Enabled=$true;$variant.Enabled=$true;$state.Text='Start mislukt';[Windows.Forms.MessageBox]::Show($_.Exception.Message)}
})
$timer.Add_Tick({if($script:worker -and ((Get-Date)-$script:started).TotalSeconds -gt 180){$timer.Stop();try{$script:worker.Kill();$script:worker.WaitForExit()}catch{};$script:worker.Dispose();$script:worker=$null;$scan.Enabled=$true;$state.Text='Time-out na 180 seconden. Probeer opnieuw.';Remove-Item -LiteralPath $script:output -Force -ErrorAction SilentlyContinue}})
$export.Add_Click({
 $dialog=New-Object Windows.Forms.SaveFileDialog;$dialog.Filter='Leesbaar rapport (*.html)|*.html|Volledige inventaris (*.json)|*.json';$dialog.FileName='Esprit-ICT-Bluetooth-rapport-'+(Get-Date -Format 'yyyyMMdd-HHmm')
 if($dialog.ShowDialog() -eq 'OK'){
  try{
   if($dialog.FilterIndex -eq 2){$script:report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8}
   else{
    $rows=foreach($c in $script:report.Checks){'<tr><td>'+[Net.WebUtility]::HtmlEncode($c.Status)+'</td><td>'+[Net.WebUtility]::HtmlEncode($c.Area+' / '+$c.Name)+'</td><td><pre>'+[Net.WebUtility]::HtmlEncode($c.Evidence)+'</pre></td><td>'+[Net.WebUtility]::HtmlEncode($c.Advice)+'</td></tr>'}
    $html='<!doctype html><html lang="nl"><meta charset="utf-8"><title>Esprit ICT Bluetooth-rapport</title><style>body{font:15px Segoe UI;margin:32px;color:#17243a}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:10px;text-align:left;vertical-align:top}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit}</style><img alt="Esprit ICT" width="260" src="data:image/png;base64,'+[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $assetRoot 'esprit-ict-logo.png')))+'"><h1>Bluetooth Check</h1><p>Variant: '+[Net.WebUtility]::HtmlEncode($script:report.Variant)+'</p><p>'+[Net.WebUtility]::HtmlEncode($script:report.CollectedAt)+' | Regels: '+$script:report.RulesVerified+'</p><p>'+[Net.WebUtility]::HtmlEncode($script:report.Verdict)+'</p><table><tr><th>Status</th><th>Controle</th><th>Bewijs</th><th>Advies</th></tr>'+($rows -join '')+'</table><h2>Bronnen</h2>'+ (($script:report.Sources | ForEach-Object {'<p>'+[Net.WebUtility]::HtmlEncode($_)+'</p>'}) -join '')+'</html>'
    $html | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8
   }
   [Windows.Forms.MessageBox]::Show('Rapport opgeslagen. Let op: inventarisrapporten bevatten apparaatnamen en hardware-ID''s. Deel ze alleen met de bedoelde ontvanger.')
  }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Opslaan mislukt')}
 }
 $dialog.Dispose()
})
$form.Add_FormClosing({$timer.Stop();if($script:worker){try{$script:worker.Kill();$script:worker.WaitForExit()}catch{};$script:worker.Dispose()};if($script:output){Remove-Item -LiteralPath $script:output -Force -ErrorAction SilentlyContinue}})
[void]$form.ShowDialog()
$timer.Dispose();$logo.Image.Dispose();$form.Icon.Dispose();$form.Dispose()

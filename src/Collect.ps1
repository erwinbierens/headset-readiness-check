param([Parameter(Mandatory=$true)][string]$OutputPath,[ValidateSet('Classic','LEAudio')][string]$Variant='Classic')
$ErrorActionPreference='Stop'
$checks=New-Object System.Collections.Generic.List[object]
$errors=New-Object System.Collections.Generic.List[string]
function Add-Check($Area,$Name,$Status,$Evidence,$Advice) {
 $checks.Add([pscustomobject]@{Area=$Area;Name=$Name;Status=$Status;Evidence=[string]$Evidence;Advice=[string]$Advice})
}
function Read-Safe($Label,[scriptblock]$Action) { try { & $Action } catch { $errors.Add("${Label}: $($_.Exception.Message)") } }
function Compare-Driver($Driver,$Minimum,$Label) {
 try {
  $ok=([version]$Driver.DriverVersion -ge [version]$Minimum)
  $status=if($ok){'OK'}else{'Advies'}
  Add-Check 'Drivers' $Label $status "$($Driver.DeviceName): $($Driver.DriverVersion); aanbevolen >= $Minimum; INF $($Driver.InfName); provider $($Driver.DriverProviderName)" 'Installeer de bij dit pc-model horende Bluetooth-, audio- en wifi-drivers via de pc-fabrikant. Het minimum is een Microsoft-aanbeveling, geen garantie voor LE Audio.'
 } catch { Add-Check 'Drivers' $Label 'Onbekend' $Driver.DriverVersion 'Controleer de versie in Apparaatbeheer.' }
}
$os=Read-Safe 'Windows' {Get-CimInstance Win32_OperatingSystem}
$cpu=@(Read-Safe 'Processor' {Get-CimInstance Win32_Processor})
$pc=Read-Safe 'Pc-model' {Get-CimInstance Win32_ComputerSystem}
$reg=Read-Safe 'Windows build' {Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'}
$devices=@(Read-Safe 'PnP' {Get-PnpDevice -PresentOnly})
$drivers=@(Read-Safe 'Drivers' {Get-CimInstance Win32_PnPSignedDriver})
$teams=@(Read-Safe 'Teams-pakket huidige gebruiker' {Get-AppxPackage -Name MSTeams})
$services=@(Read-Safe 'Services' {Get-Service | Where-Object {$_.Name -match '^(bthserv|BTAGService|BluetoothUserService_|Audiosrv|AudioEndpointBuilder)'}})
$build=0
if($os){$build=[int]$os.BuildNumber}
if($os){
 $status=if($build -ge 22000 -and $os.ProductType -eq 1){'OK'}else{'Probleem'}
 Add-Check 'Classic + LE' 'Windows 11 desktop' $status "$($os.Caption); build $build.$($reg.UBR); $($reg.DisplayVersion); $($os.OSArchitecture)" 'Gebruik Windows 11 op een ondersteunde pc en installeer Windows Update.'
 Add-Check 'LE Audio' 'Windows-basis voor LE Audio' $(if($build -ge 22621 -and $os.ProductType -eq 1){'OK'}else{'Probleem'}) "Build $build; LE Audio vereist Windows 11 22H2 of nieuwer." 'Werk Windows bij. Daarnaast zijn geschikte Bluetooth- en codec-hardware en OEM-drivers vereist.'
 Add-Check 'LE Audio' 'Stereo tijdens microfoongebruik: OS-basis' $(if($build -gt 26100 -or ($build -eq 26100 -and $reg.UBR -ge 4484)){'OK'}else{'Advies'}) "Build $build.$($reg.UBR); OS-basis 26100.4484. Dit bewijst geen Super Wideband Stereo-ondersteuning." 'Installeer Windows-updates en OEM-drivers. Controleer daarna de stereo-optie bij het uitvoerapparaat in Geluidsinstellingen.'
}else{Add-Check 'Classic + LE' 'Windows' 'Onbekend' 'Windows-informatie niet leesbaar.' 'Zie verzamelfouten in het rapport.'}
Add-Check 'Hardware' 'Pc en processor' 'Handmatig' "$($pc.Manufacturer) $($pc.Model); $(($cpu.Name) -join '; ')" 'Vergelijk met de actuele Microsoft-aanbeveling: Intel Core generatie 12+, AMD Windows 11-compatibel, Snapdragon X+ of NVIDIA RTX Spark+. Windows-installatie alleen bewijst hardwaregeschiktheid niet.'
$radios=@($devices | Where-Object {$_.Class -eq 'Bluetooth' -and $_.InstanceId -notmatch '^(BTH|SWD)' -and $_.InstanceId -match '^(USB|PCI|ACPI|UART)'})
Add-Check 'Classic + LE' 'Fysieke Bluetooth-controller' $(if($radios.Count){'OK'}elseif($errors.Count){'Onbekend'}else{'Probleem'}) "$(($radios | ForEach-Object {"$($_.FriendlyName) [$($_.Status)] $($_.InstanceId)"}) -join "`n")" 'Geen controller? Schakel Bluetooth in, controleer BIOS/radioknop en installeer de OEM-driver. Een USB-audiodongle is geen Bluetooth-controller.'
foreach($r in $radios){
 $props=@(Read-Safe "Eigenschappen $($r.FriendlyName)" {Get-PnpDeviceProperty -InstanceId $r.InstanceId})
 $service=($props | Where-Object KeyName -eq 'DEVPKEY_Device_Service').Data
 Add-Check 'Stack' "Controller: $($r.FriendlyName)" $(if($r.Status -ne 'OK'){'Probleem'}elseif($service -eq 'BTHUSB'){'OK'}else{'Onbekend'}) "PnP-status $($r.Status); transportservice $service; $($r.InstanceId)" 'BTHUSB is bewijs voor Microsoft USB Bluetooth-transport, niet voor de volledige audioketen. Controleer bij problemen de OEM-driver en apparaatstatus.'
 $lmp=$props | Where-Object {$_.KeyName -match 'LMP.*Ver|RadioLmpVersion'} | Select-Object -First 1
 $bt='Onbekend'
 if($lmp){$map=@{6='4.0';7='4.1';8='4.2';9='5.0';10='5.1';11='5.2';12='5.3';13='5.4';14='6.0'}; $bt=$map[[int]$lmp.Data];if(!$bt){$bt="LMP $($lmp.Data)"}}
 Add-Check 'Hardware' "Bluetooth Core-versie: $($r.FriendlyName)" $(if($lmp){'Info'}else{'Onbekend'}) "$bt; $(if($lmp){$lmp.KeyName}else{'Geen LMP-versie gepubliceerd via PnP.'})" 'Controleer zo nodig Apparaatbeheer > Bluetooth-radio > Geavanceerd > firmware/LMP. Bluetooth 5.2 of hoger bewijst geen LE Audio-ondersteuning.'
 Add-Check 'Hardware' "Geintegreerde radio: $($r.FriendlyName)" 'Handmatig' 'Een interne radio kan ook via USB zijn aangesloten; de busnaam bewijst niet of een adapter extern is.' 'Controleer de pc-specificaties en eventuele ingestoken adapters. Microsoft certificeert de native ervaring met een geintegreerde radio.'
}
$btDevices=@($devices | Where-Object {$_.InstanceId -match '^BTH(ENUM|LEDEVICE)\\'})
Add-Check 'Verbinding' 'Windows Bluetooth-apparaatinstanties' $(if($btDevices.Count){'Info'}else{'Handmatig'}) "$(($btDevices | ForEach-Object {"$($_.FriendlyName) | $($_.InstanceId) | $($_.Status)"}) -join "`n")" 'Selecteer de bedoelde headset in Windows Bluetooth-instellingen. Een PnP-instantie bewijst geen actieve audioverbinding of gebruikte codec.'
$audio=@($devices | Where-Object {$_.Class -in @('AudioEndpoint','MEDIA')})
Add-Check 'Audio' 'Aanwezige audioapparaten' 'Info' "$(($audio | ForEach-Object {"$($_.FriendlyName) | $($_.Status) | $($_.InstanceId)"}) -join "`n")" 'Controleer in Teams > Instellingen > Apparaten dat zowel luidspreker als microfoon van de bedoelde headset zijn geselecteerd. USB AUDIO kan een dongle of ander audioapparaat zijn.'
foreach($s in $services){Add-Check 'Services' $s.Name $(if($s.Status -eq 'Running'){'OK'}else{'Advies'}) "Status $($s.Status); starttype $($s.StartType)" 'Audio-services horen actief te zijn tijdens gebruik. Bluetooth-gebruikersservices en BTAGService kunnen op aanvraag starten; een gestopte service is op zichzelf geen incompatibiliteit.'}
foreach($name in @('bthserv','Audiosrv','AudioEndpointBuilder')){if(!($services | Where-Object Name -eq $name)){Add-Check 'Services' $name 'Onbekend' 'Niet gevonden of niet leesbaar.' 'Controleer services.msc en verzamelfouten.'}}
$relevant=@($drivers | Where-Object {$_.DeviceClass -in @('BLUETOOTH','MEDIA','NET') -or $_.DeviceName -match 'Smart Sound'})
$intelBt=@($relevant | Where-Object {$_.DeviceName -match 'Intel.*Bluetooth'})
$intelWifi=@($relevant | Where-Object {$_.DeviceName -match 'Intel.*(Wi-Fi|Wireless|WiFi)' -and $_.DeviceName -notmatch 'Bluetooth'})
foreach($d in $intelBt){Compare-Driver $d '23.70.0.0' 'Intel Bluetooth (aanbeveling)'}
foreach($d in $intelWifi){Compare-Driver $d '23.70.0.0' 'Intel wifi (aanbeveling)'}
$sst=@($relevant | Where-Object {$_.DeviceName -match '(Smart Sound|SST)'})
$cpuName=($cpu.Name -join ' ')
$sstMin=$null
if($cpuName -match 'Ultra.*\b2\d\d\w*\b'){$sstMin='20.42.11233.0'}
if($cpuName -match 'Ultra.*\b1\d\d\w*\b'){$sstMin='20.40.11112.5'}
if($cpuName -match '(12th|13th) Gen|i[3579]-1[23]\d{3}'){$sstMin='10.29.0.11261'}
foreach($d in $sst){if($sstMin){Compare-Driver $d $sstMin 'Intel SST (aanbeveling)'}else{Add-Check 'Drivers' 'Intel SST' 'Handmatig' "$($d.DeviceName): $($d.DriverVersion)" 'Voor deze CPU is geen eenduidige minimumregel gekozen. Controleer het pc-model en de actuele Microsoft/OEM-documentatie.'}}
Add-Check 'Drivers' 'Driveractualiteit en headsetfirmware' 'Handmatig' 'Geinstalleerde drivers staan in het inventarisrapport. Er is geen universele offline database met de nieuwste geschikte OEM-versies.' 'Controleer BIOS, chipset, Bluetooth, wifi en audiocodec bij de pc-fabrikant en headsetfirmware bij de headsetfabrikant. Installeer geen willekeurige driver-updatetool.'
if($teams.Count){foreach($t in $teams){Add-Check 'Teams' 'Teams desktop huidige gebruiker' $(if([version]$t.Version -ge [version]'24335.208.3315.1951'){'OK'}else{'Probleem'}) "$($t.Name) $($t.Version)" 'Werk Teams bij via Teams > Instellingen en meer > Controleren op updates. Gebruik de desktop-app.'}}else{Add-Check 'Teams' 'Teams desktop huidige gebruiker' 'Onbekend' 'Geen MSTeams AppX-pakket gevonden; andere installatievormen, VDI of andere gebruikers zijn hiermee niet uitgesloten.' 'Open Teams > Instellingen > Over Teams en controleer versie >= 24335.208.3315.1951. De browserclient valt buiten deze native certificeringscontrole.'}
Add-Check 'LE Audio' 'LE Audio-schakelaar en codec/OEM-keten' 'Handmatig' 'Bluetooth LE of een recente radioversie bewijst geen LE Audio. De instelling wordt niet via een ongedocumenteerde registersleutel geraden.' 'Open Bluetooth en apparaten > Apparaten. Controleer of Gebruik LE Audio indien beschikbaar aanwezig en ingeschakeld is. Ontbreekt deze, dan ondersteunt de huidige pc-/driverconfiguratie LE Audio niet. Controleer ook LE Audio/TMAP bij de headsetfabrikant.'
Add-Check 'Verbinding' 'Actieve native route en headsetcertificering' 'Handmatig' 'Aanwezige apparaten zijn geinventariseerd; de actieve route in Teams en exacte headsetvariant zijn niet automatisch bewezen.' 'Koppel de headset direct via Windows, controleer de exacte modelvariant in Microsofts lijst en selecteer deze in Teams. Test zonder de USB-audiodongle. Controleer of je Classic of Dual Mode-certificering hebt.'
Add-Check 'Teams' 'Praktijktest en beleidsinstellingen' 'Handmatig' 'Teams-apparaatkeuze, tenantbeleid, actieve codec, firmware en radio-interferentie zijn niet bewezen door de inventarisatie.' 'Voer een Teams-testgesprek uit. Test horen, spreken, opnemen/ophangen, Teams-knop en mute-sync in beide richtingen. Controleer microfoontoegang in Windows, meerdere tenants en meerdere gekoppelde Bluetooth-headsets. Bevestig Spatial Audio alleen bij LE Audio plus Super Wideband Stereo.'
foreach($e in $errors){Add-Check 'Verzameling' 'Niet volledig uitgelezen' 'Onbekend' $e 'Probeer opnieuw. Alleen indien nodig uitvoeren als administrator; pas geen beveiligingsbeleid aan.'}
if($Variant -eq 'Classic'){
 $filtered=@($checks | Where-Object Area -ne 'LE Audio')
 $checks.Clear();foreach($item in $filtered){$checks.Add($item)}
 Add-Check 'Variant' 'Native Bluetooth Classic (A2DP / HFP)' 'Handmatig' 'Deze scan beoordeelt de Classic-route. LE Audio is voor deze keuze geen voorwaarde.' 'Controleer de exacte Classic-certificering en test gesprekken via de rechtstreeks in Windows gekoppelde headset. A2DP is voor weergave; HFP voor gesprekken met microfoon. Bevestig de route in een praktijktest.'
}else{
 Add-Check 'Variant' 'Bluetooth LE Audio (TMAP)' 'Handmatig' 'Deze scan beoordeelt de LE Audio-route. Algemene native Bluetooth-voorwaarden blijven van toepassing.' 'Bevestig LE Audio op zowel pc als headset, de Windows LE Audio-schakelaar, passende OEM-audiodrivers en de exacte Dual Mode-certificering. Classic-only certificering bewijst geen gecertificeerde LE Audio-ervaring.'
}
$report=[ordered]@{SchemaVersion=2;Variant=$Variant;CollectedAt=(Get-Date).ToString('o');RulesVerified='2026-11-23';Verdict='Nog niet volledig vastgesteld: rond alle handmatige en onbekende controles af. OK betekent alleen dat de afzonderlijke controle slaagt.';Sources=@('https://learn.microsoft.com/en-us/microsoftteams/devices/bluetooth-devices','https://support.microsoft.com/en-gb/windows/hardware/bluetooth/check-if-a-windows-11-device-supports-bluetooth-low-energy-audio','https://support.microsoft.com/en-us/windows/hardware/bluetooth/configuring-bluetooth-le-audio-quality-settings-on-windows-11');Checks=@($checks.ToArray());Inventory=@{Computer=$pc | Select-Object Manufacturer,Model;CPU=$cpu | Select-Object Name;Drivers=$relevant | Select-Object DeviceName,DeviceID,DriverVersion,DriverDate,DriverProviderName,InfName,IsSigned;Devices=$devices | Select-Object FriendlyName,Class,InstanceId,Status;Services=$services | Select-Object Name,Status,StartType};Errors=@($errors.ToArray())}
$report | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $OutputPath -Encoding UTF8





$ErrorActionPreference='Stop'
function Get-CimInstance($ClassName){switch($ClassName){
 'Win32_OperatingSystem'{[pscustomobject]@{BuildNumber="$global:testBuild";ProductType=1;Caption='Windows 11';OSArchitecture='64-bit'}}
 'Win32_Processor'{[pscustomobject]@{Name='Intel Core Ultra 7 258V'}}
 'Win32_ComputerSystem'{[pscustomobject]@{Manufacturer='Test';Model='Fixture'}}
 'Win32_PnPSignedDriver'{[pscustomobject]@{DeviceClass='BLUETOOTH';DeviceName='Intel Wireless Bluetooth';DriverVersion=$global:testDriver;InfName='test.inf'}}
}}
function Get-ItemProperty{[pscustomobject]@{UBR=4484;DisplayVersion='24H2'}}
function Get-PnpDevice{[pscustomobject]@{Class='Bluetooth';InstanceId='USB\VID_TEST';Status='OK';FriendlyName='Test radio'}}
function Get-PnpDeviceProperty{[pscustomobject]@{KeyName='DEVPKEY_Device_Service';Data='BTHUSB'}}
function Get-AppxPackage{[pscustomobject]@{Name='MSTeams';Version=$global:testTeams}}
function Get-Service{foreach($n in @('bthserv','Audiosrv','AudioEndpointBuilder')){[pscustomobject]@{Name=$n;Status='Running';StartType='Automatic'}}}
$out=Join-Path $PSScriptRoot (([guid]::NewGuid().ToString('N'))+'.json')
try{
 foreach($case in @(
  @(22000,'23.69.0.0','24335.208.3315.1950','Probleem','Advies','Probleem'),
  @(22621,'23.70.0.0','24335.208.3315.1951','OK','OK','OK')
 )){
  $global:testBuild=$case[0];$global:testDriver=$case[1];$global:testTeams=$case[2]
  & (Join-Path $PSScriptRoot '..\src\Collect.ps1') -OutputPath $out -Variant LEAudio
  $r=Get-Content -LiteralPath $out -Raw | ConvertFrom-Json
  $actual=@(($r.Checks | Where-Object Name -eq 'Windows-basis voor LE Audio').Status,($r.Checks | Where-Object Name -eq 'Intel Bluetooth (aanbeveling)').Status,($r.Checks | Where-Object Name -eq 'Teams desktop huidige gebruiker').Status)
  for($i=0;$i -lt 3;$i++){if($actual[$i] -ne $case[$i+3]){throw "Case $($case[0]), check ${i}: $($actual[$i])"}}
  if($r.Errors.Count){throw 'Unexpected collection errors'}
  if(!($r.Checks | Where-Object { $_.Name -eq 'LE Audio-schakelaar en codec/OEM-keten' -and $_.Status -eq 'Handmatig'})){throw 'LE Audio must not be inferred from versions'}
 }
 & (Join-Path $PSScriptRoot '..\src\Collect.ps1') -OutputPath $out -Variant Classic
 $classic=Get-Content -LiteralPath $out -Raw | ConvertFrom-Json
 if($classic.Variant -ne 'Classic' -or @($classic.Checks | Where-Object Area -eq 'LE Audio').Count){throw 'Classic contains LE Audio requirements'}
 if(!($classic.Checks | Where-Object Area -eq 'Teams')){throw 'Classic must retain Teams checks'}
 'PASS: variantselectie Classic/LE Audio en minimumgrenzen Windows, Intel Bluetooth, Teams en handmatige LE Audio-bevestiging.'
}finally{Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue}





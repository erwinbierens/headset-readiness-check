$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
 New-Item -ItemType Directory -Force dist | Out-Null
 $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
 & $compiler /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll /win32icon:assets\esprit-ict.ico /resource:assets\esprit-ict-logo.png,esprit-ict-logo.png /resource:assets\esprit-ict.ico,esprit-ict.ico /resource:src\App.ps1,App.ps1 /resource:src\Collect.ps1,Collect.ps1 /out:dist\EspritICTBluetoothCheck.exe src\Launcher.cs
 if($LASTEXITCODE -ne 0){throw 'Compilatie mislukt'}
 Get-FileHash dist\EspritICTBluetoothCheck.exe -Algorithm SHA256
} finally {Pop-Location}

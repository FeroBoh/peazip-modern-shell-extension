[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PeaZipExe)
$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $PeaZipExe).ProviderPath
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw 'Not a file.' }
if ([IO.Path]::GetFileName($resolved) -ine 'peazip.exe') { throw 'Select peazip.exe.' }
New-Item -Path 'HKCU:\Software\PeaZipModernMenu' -Force | Out-Null
New-ItemProperty -Path 'HKCU:\Software\PeaZipModernMenu' -Name 'ExecutablePath' -Value $resolved -PropertyType String -Force | Out-Null
Write-Host "PeaZip executable configured: $resolved"

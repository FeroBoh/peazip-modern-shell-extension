# Compile the per-user companion installer after Build-MSIX.ps1 succeeds.
[CmdletBinding()]
param([string]$IsccPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$msix = Join-Path $root 'out\PeaZip.ModernMenu.Community_1.2.1.0_x64.msix'
if (-not (Test-Path -LiteralPath $msix)) { throw 'MSIX not found. Run tools\Build-MSIX.ps1 first.' }
if (-not (Test-Path -LiteralPath (Join-Path $root 'out\stage\PeaZipMenuConfig.exe'))) {
    throw 'The native configuration executable was not built.'
}
if (-not $IsccPath) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { $IsccPath = $cmd.Source }
}
if (-not $IsccPath) {
    $candidates = @(
        "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    )
    $IsccPath = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $IsccPath) { throw 'ISCC.exe missing. Install Inno Setup 6 or 7, or pass -IsccPath.' }
$iss = Join-Path $root 'installer\PeaZip-ModernMenu.iss'
& $IsccPath $iss
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
Write-Host ('Installer output: ' + (Join-Path $root 'out\installer\PeaZip-ModernMenu-Setup-v1.2.1.exe'))

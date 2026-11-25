# After a successful community build, stage ONLY public installer/distribution artifacts.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'out'
$release = Join-Path $out 'release-v1.2.2'
$files = @(
    (Join-Path $out 'installer\PeaZip-ModernMenu-Setup-v1.2.2.exe'),
    (Join-Path $out 'PeaZipModernMenuCommunity.cer')
)
foreach ($file in $files) { if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing release file: $file" } }
New-Item -Path $release -ItemType Directory -Force | Out-Null
$checksums = @()
foreach ($file in $files) {
    $destination = Join-Path $release (Split-Path $file -Leaf)
    Copy-Item -LiteralPath $file -Destination $destination -Force
    $sha = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksums += "$sha  $(Split-Path $destination -Leaf)"
}
[System.IO.File]::WriteAllLines((Join-Path $release 'SHA256SUMS.txt'), $checksums, ([System.Text.UTF8Encoding]::new($false)))
Write-Host "Release files: $release"
Write-Host 'Do not publish PFX/private keys. Build and test the exact EXE before release.'

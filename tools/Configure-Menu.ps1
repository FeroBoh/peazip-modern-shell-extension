# Compatibility launcher for native configuration GUI; v1.2 has no PowerShell GUI dependency.
$root = Split-Path -Parent $PSScriptRoot
$candidates = @((Join-Path $root 'out\stage\PeaZipMenuConfig.exe'),
                (Join-Path $env:LOCALAPPDATA 'Programs\PeaZip Modern Menu\PeaZipMenuConfig.exe'))
$exe = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $exe) { throw 'Build the project with Build-MSIX.ps1, or install with the Inno Setup installer.' }
& $exe
exit $LASTEXITCODE

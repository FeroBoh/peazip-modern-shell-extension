# Compatibility entry point. Does not uninstall PeaZip itself.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Uninstall-Companion.ps1') @args
exit $LASTEXITCODE

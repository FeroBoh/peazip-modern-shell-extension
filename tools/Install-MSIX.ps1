# Compatibility entry point. Per-user installation/upgrade; does not import certificates.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Install-Companion.ps1') @args
exit $LASTEXITCODE

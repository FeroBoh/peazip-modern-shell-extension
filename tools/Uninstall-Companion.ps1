# Per-user removal of the companion MSIX ONLY, with optional companion registry cleanup.
# Never remove PeaZip, its archive files, classic menu, or certificates.
[CmdletBinding()]
param([switch]$RemoveSettings, [string]$ManifestPath)
$ErrorActionPreference = 'Stop'
$logFile = Join-Path $env:TEMP 'PeaZipModernMenu-Uninstall.log'
function Write-DeploymentLog([string]$message) {
    try { Add-Content -LiteralPath $logFile -Value ("$(Get-Date -Format o) $message") -ErrorAction Stop } catch { }
}
Write-DeploymentLog "=== Uninstall started (PID $PID, user $env:USERNAME) ==="
try {
    if (-not $ManifestPath) { $ManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'out\stage\AppxManifest.xml' }
    [xml]$manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop
    $packageName = [string]$manifest.Package.Identity.Name
    $publisher = [string]$manifest.Package.Identity.Publisher
    $maxVersion = [version]$manifest.Package.Identity.Version
    if ($packageName -ne 'PeaZip.ModernMenu.Community') { throw "Unexpected package identity: $packageName" }

    $existing = Get-AppxPackage -Name $packageName |
        Where-Object { $_.Publisher -eq $publisher } |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($existing) {
        if ($existing.Version -gt $maxVersion) {
            throw "Version $($existing.Version) is newer than this uninstaller ($maxVersion); refusing to remove a future package."
        }
        Write-DeploymentLog "Removing $($existing.PackageFullName) from CURRENT user only."
        Remove-AppxPackage -Package $existing.PackageFullName -ErrorAction Stop
        $stillThere = Get-AppxPackage -Name $packageName |
            Where-Object { $_.Publisher -eq $publisher } | Select-Object -First 1
        if ($stillThere) { throw "MSIX is still registered: $($stillThere.PackageFullName)" }
        Write-DeploymentLog 'SUCCESS: MSIX was unregistered from the current account.'
    } else {
        Write-DeploymentLog 'No matching companion MSIX registered for the current user.'
    }

    # Deliberately AFTER MSIX removal: failed deployment must never destroy preferences.
    if ($RemoveSettings) {
        Remove-Item 'HKCU:\Software\PeaZipModernMenu' -Recurse -Force -ErrorAction SilentlyContinue
        Write-DeploymentLog 'Optional companion HKCU settings removed.'
    } else {
        Write-DeploymentLog 'Companion HKCU settings preserved for reinstallation.'
    }
    Write-DeploymentLog 'SUCCESS: Uninstall completed. PeaZip and certificates were not modified.'
    exit 0
}
catch {
    $errorText = 'MSIX uninstall failed: ' + $_.Exception.Message
    Write-DeploymentLog $errorText
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { Write-DeploymentLog ('Windows deployment details: ' + $_.ErrorDetails.Message) }
    [Console]::Error.WriteLine($errorText)
    exit 1
}

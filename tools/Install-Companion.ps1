# Per-user install/upgrade of the companion MSIX. The main PeaZip install is never modified.
# 1.2.1: when an older package is loaded by Explorer/COM surrogate, request a
# targeted app shutdown to avoid MSIX deployment error 0x80073D02.
[CmdletBinding()]
param(
    [string]$PackagePath,
    [string]$ManifestPath,
    [switch]$AllowDowngrade # Recovery only; the Inno Setup installer never enables it.
)
$ErrorActionPreference = 'Stop'
$logFile = Join-Path $env:TEMP 'PeaZipModernMenu-Install.log'
function Write-DeploymentLog([string]$message) {
    try { Add-Content -LiteralPath $logFile -Value ("$(Get-Date -Format o) $message") -ErrorAction Stop } catch { }
}
Write-DeploymentLog "=== Install / upgrade started (PID $PID, user $env:USERNAME) ==="
try {
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $PackagePath) { $PackagePath = Join-Path $root 'out\PeaZip.ModernMenu.Community_1.2.1.0_x64.msix' }
    if (-not $ManifestPath) { $ManifestPath = Join-Path $root 'out\stage\AppxManifest.xml' }
    $PackagePath = (Resolve-Path -LiteralPath $PackagePath -ErrorAction Stop).Path
    $ManifestPath = (Resolve-Path -LiteralPath $ManifestPath -ErrorAction Stop).Path
    [xml]$manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop
    $target = [version]$manifest.Package.Identity.Version
    $packageName = [string]$manifest.Package.Identity.Name
    $publisher = [string]$manifest.Package.Identity.Publisher
    if ($packageName -ne 'PeaZip.ModernMenu.Community') { throw "Unexpected package identity: $packageName" }

    # Never replace a package of the same name with an unexpected publisher.
    # Production signing that changes the publisher needs its own migration plan.
    $candidates = @(Get-AppxPackage -Name $packageName)
    $conflicting = $candidates | Where-Object { $_.Publisher -ne $publisher } | Select-Object -First 1
    if ($conflicting) {
        throw "A package with a different publisher already exists: $($conflicting.Publisher)"
    }
    $existing = $candidates | Sort-Object Version -Descending | Select-Object -First 1
    if ($existing -and $existing.Version -eq $target) {
        Write-DeploymentLog "Already installed: $packageName $target; no MSIX operation required."
        Write-Host "Already installed: $packageName $target"
        exit 0
    }
    if ($existing -and $existing.Version -gt $target -and -not $AllowDowngrade) {
        throw "Installed version $($existing.Version) is newer than $target. Downgrade refused."
    }

    $addArgs = @{ Path = $PackagePath; ErrorAction = 'Stop' }
    if ($existing) {
        Write-DeploymentLog "Updating $($existing.Version) -> $target using -ForceTargetApplicationShutdown. Windows may close processes hosting this extension."
        $addArgs.ForceTargetApplicationShutdown = $true
    } else {
        Write-DeploymentLog "Fresh installation of $packageName $target."
    }
    if ($AllowDowngrade) { $addArgs.ForceUpdateFromAnyVersion = $true }
    Add-AppxPackage @addArgs

    $registered = Get-AppxPackage -Name $packageName |
        Where-Object { $_.Publisher -eq $publisher } |
        Sort-Object Version -Descending | Select-Object -First 1
    if (-not $registered -or $registered.Version -ne $target -or $registered.Status -ne 'Ok') {
        $actual = if ($registered) { "version $($registered.Version), status $($registered.Status)" } else { 'not registered' }
        throw "Deployment returned without error, but expected $target / Ok; actual: $actual"
    }
    Write-DeploymentLog "SUCCESS: $($registered.PackageFullName), status $($registered.Status)."
    Write-Host "SUCCESS: $($registered.Name), version $($registered.Version)"
    exit 0
}
catch {
    $errorText = 'MSIX install / upgrade failed: ' + $_.Exception.Message
    Write-DeploymentLog $errorText
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        Write-DeploymentLog ('Windows deployment details: ' + $_.ErrorDetails.Message)
    }
    if ($errorText -match '0x80073D02') {
        Write-DeploymentLog 'The package remains in use. Close Explorer windows / sign out and retry. Existing MSIX is not removed.'
    }
    [Console]::Error.WriteLine($errorText)
    exit 1
}

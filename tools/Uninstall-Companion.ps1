# Per-user removal of the companion MSIX ONLY, with optional companion registry cleanup.
# Never remove PeaZip, its archives, or its classic menu.
[CmdletBinding()]
param([switch]$RemoveSettings, [string]$ManifestPath,
      [switch]$RemoveTrust, [string]$CertificatePath, [string]$TrustHelperPath,
      [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedCertSha256)
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

    if ($RemoveTrust) {
        if (-not $CertificatePath -or -not $TrustHelperPath) { throw 'Certificate cleanup files missing.' }
        if ((Get-FileHash -LiteralPath $CertificatePath -Algorithm SHA256).Hash.ToUpperInvariant() -ne $ExpectedCertSha256.ToUpperInvariant()) {
            throw 'SECURITY: certificate hash differs from the pinned installer identity. Trust will not be removed.'
        }
        $cert=[System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath)
        $thumb=$cert.Thumbprint
        $record="HKLM:\SOFTWARE\PeaZipModernMenuCommunity\ManagedTrust\$thumb"
        if (Test-Path $record) {
            Write-DeploymentLog "Requesting UAC to remove installer-managed certificate trust $thumb."
            $args='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $TrustHelperPath + '"' +
                ' -Action Remove -CertificatePath "' + $CertificatePath + '" -Thumbprint ' + $thumb +
                ' -ExpectedCertSha256 ' + $ExpectedCertSha256.ToUpperInvariant()
            $proc=Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs `
                -ArgumentList $args -Wait -PassThru -ErrorAction Stop
            if ($proc.ExitCode -ne 0) { throw 'Certificate trust cleanup was declined or failed. See certificate log.' }
            Write-DeploymentLog "Certificate trust cleanup finished: $thumb"
        } else {
            Write-DeploymentLog "Cert $thumb was not marked as installer-managed; preserving pre-existing trust."
        }
    }

    # Deliberately AFTER MSIX removal: failed deployment must never destroy preferences.
    if ($RemoveSettings) {
        Remove-Item 'HKCU:\Software\PeaZipModernMenu' -Recurse -Force -ErrorAction SilentlyContinue
        Write-DeploymentLog 'Optional companion HKCU settings removed.'
    } else {
        Write-DeploymentLog 'Companion HKCU settings preserved for reinstallation.'
    }
    Write-DeploymentLog 'SUCCESS: Uninstall completed. PeaZip was not modified.'
    exit 0
}
catch {
    $errorText = 'MSIX uninstall failed: ' + $_.Exception.Message
    Write-DeploymentLog $errorText
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { Write-DeploymentLog ('Windows deployment details: ' + $_.ErrorDetails.Message) }
    [Console]::Error.WriteLine($errorText)
    exit 1
}

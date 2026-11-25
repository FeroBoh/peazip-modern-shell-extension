# Per-user install/upgrade of the companion MSIX. The main PeaZip install is never modified.
# 1.2.2: when an older package is loaded by Explorer/COM surrogate, request a
# targeted app shutdown to avoid MSIX deployment error 0x80073D02.
[CmdletBinding()]
param(
    [string]$PackagePath,
    [string]$ManifestPath,
    [switch]$AllowDowngrade, # Recovery only; Inno Setup never enables it.
    [string]$CertificatePath,
    [string]$TrustHelperPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedCertSha256,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedMsixSha256,
    [switch]$AllowTrustImport
)
$ErrorActionPreference = 'Stop'
$logFile = Join-Path $env:TEMP 'PeaZipModernMenu-Install.log'
function Write-DeploymentLog([string]$message) {
    try { Add-Content -LiteralPath $logFile -Value ("$(Get-Date -Format o) $message") -ErrorAction Stop } catch { }
}
Write-DeploymentLog "=== Install / upgrade started (PID $PID, user $env:USERNAME) ==="
$importedTrustThisRun = $false
try {
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $PackagePath) { $PackagePath = Join-Path $root 'out\PeaZip.ModernMenu.Community_1.2.3.0_x64.msix' }
    if (-not $ManifestPath) { $ManifestPath = Join-Path $root 'out\stage\AppxManifest.xml' }
    $PackagePath = (Resolve-Path -LiteralPath $PackagePath -ErrorAction Stop).Path
    $ManifestPath = (Resolve-Path -LiteralPath $ManifestPath -ErrorAction Stop).Path
    [xml]$manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop
    $target = [version]$manifest.Package.Identity.Version
    $packageName = [string]$manifest.Package.Identity.Name
    $publisher = [string]$manifest.Package.Identity.Publisher
    if ($packageName -ne 'PeaZip.ModernMenu.Community') { throw "Unexpected package identity: $packageName" }

    # Validate the attached public key BEFORE asking Windows to trust it.
    if (-not $CertificatePath -or -not $TrustHelperPath -or -not $AllowTrustImport) {
        throw 'Community installation requires explicit consent and a bundled public certificate/trust helper.'
    }
    $CertificatePath = (Resolve-Path -LiteralPath $CertificatePath -ErrorAction Stop).Path
    $TrustHelperPath = (Resolve-Path -LiteralPath $TrustHelperPath -ErrorAction Stop).Path
    # SHA-256 pins are embedded into the compiling Inno EXE, not supplied by a mutable sidecar file.
    # Check certificate file bytes AND parsed DER certificate before asking for UAC trust.
    $expectedCert = $ExpectedCertSha256.ToUpperInvariant()
    $actualCertFile = (Get-FileHash -LiteralPath $CertificatePath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualCertFile -ne $expectedCert) { throw 'SECURITY: bundled .cer SHA-256 does not match the installer-pinned fingerprint.' }
    $certificate=[System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $actualDer = [BitConverter]::ToString($sha256.ComputeHash($certificate.RawData)).Replace('-','').ToUpperInvariant()
    } finally { $sha256.Dispose() }
    if ($actualDer -ne $expectedCert) { throw 'SECURITY: parsed certificate DER SHA-256 does not match installer pin.' }
    $actualMsixFile = (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualMsixFile -ne $ExpectedMsixSha256.ToUpperInvariant()) {
        throw 'SECURITY: bundled signed MSIX SHA-256 does not match installer pin.'
    }
    Write-DeploymentLog "Pinned cert SHA-256 verified: $expectedCert"
    Write-DeploymentLog "Pinned MSIX SHA-256 verified: $actualMsixFile"
    if ($certificate.Subject -ne $publisher -or $certificate.Issuer -ne $publisher) {
        throw 'The bundled certificate publisher does not match the MSIX manifest.'
    }
    $auth=Get-AuthenticodeSignature -LiteralPath $PackagePath
    if (-not $auth.SignerCertificate -or $auth.SignerCertificate.Thumbprint -ne $certificate.Thumbprint) {
        throw 'Package signature does not match the certificate bundled with the installer.'
    }
    $thumb=$certificate.Thumbprint

    # Import the public leaf to the MACHINE TrustedPeople store (only if absent),
    # via a separately elevated UAC process. The MSIX remains per-user.
    if (-not (Test-Path "Cert:\LocalMachine\TrustedPeople\$thumb")) {
        Write-DeploymentLog "User consented to public code-signing trust for cert $thumb. Requesting UAC elevation."
        $args = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $TrustHelperPath + '"' +
            ' -Action Install -CertificatePath "' + $CertificatePath + '" -Thumbprint ' + $thumb +
            ' -ExpectedCertSha256 ' + $expectedCert
        $proc=Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs `
            -ArgumentList $args -Wait -PassThru -ErrorAction Stop
        if ($proc.ExitCode -ne 0) { throw "Certificate installation failed or was cancelled (exit $($proc.ExitCode))." }
        if (-not (Test-Path "Cert:\LocalMachine\TrustedPeople\$thumb")) { throw 'TrustedPeople import was not confirmed.' }
        $importedTrustThisRun = $true
        Write-DeploymentLog "Public certificate trusted: $thumb"
    } else {
        Write-DeploymentLog "Signing certificate was already trusted: $thumb; no elevated trust action required."
    }

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
    $originalError = $_
    # Best-effort rollback: do not leave a NEW trusted leaf behind if deployment fails.
    # The elevated helper refuses removal if another account still has the package.
    if ($importedTrustThisRun -and $TrustHelperPath -and $CertificatePath -and $thumb) {
        try {
            $cleanupArgs='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $TrustHelperPath + '"' +
                ' -Action Remove -CertificatePath "' + $CertificatePath + '" -Thumbprint ' + $thumb +
                ' -ExpectedCertSha256 ' + $expectedCert
            $cleanup=Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
                -Verb RunAs -ArgumentList $cleanupArgs -Wait -PassThru -ErrorAction Stop
            if ($cleanup.ExitCode -ne 0) { Write-DeploymentLog 'WARNING: automatic certificate cleanup failed; review TrustedPeople manually.' }
            else { Write-DeploymentLog 'Rolled back installer-managed cert trust after failed deployment (unless shared by another user).' }
        } catch { Write-DeploymentLog ('WARNING: could not roll back new certificate trust: ' + $_.Exception.Message) }
    }
    $errorText = 'MSIX install / upgrade failed: ' + $originalError.Exception.Message
    Write-DeploymentLog $errorText
    if ($originalError.ErrorDetails -and $originalError.ErrorDetails.Message) {
        Write-DeploymentLog ('Windows deployment details: ' + $originalError.ErrorDetails.Message)
    }
    if ($errorText -match '0x80073D02') {
        Write-DeploymentLog 'The package remains in use. Close Explorer windows / sign out and retry. Existing MSIX is not removed.'
    }
    [Console]::Error.WriteLine($errorText)
    exit 1
}

# Elevation-only helper. This script NEVER gets a private key or a PFX.
# Only the specific certificate installed by this companion may be removed.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Install','Remove')][string]$Action,
    [Parameter(Mandatory=$true)][string]$CertificatePath,
    [Parameter(Mandatory=$true)][string]$Thumbprint,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedCertSha256
)
$ErrorActionPreference = 'Stop'
$logFile = Join-Path $env:TEMP 'PeaZipModernMenu-Certificate.log'
function Log([string]$message) { Add-Content $logFile -Value "$(Get-Date -Format o) $message" -ErrorAction SilentlyContinue }
try {
    $identity=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=[System.Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator permission is required ONLY to change the LocalMachine TrustedPeople store.'
    }
    if (-not (Test-Path -LiteralPath $CertificatePath -PathType Leaf)) { throw 'Certificate file not found.' }
    $pinned = $ExpectedCertSha256.ToUpperInvariant()
    $actualFileSha256 = (Get-FileHash -LiteralPath $CertificatePath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualFileSha256 -ne $pinned) { throw 'SECURITY: helper rejected certificate SHA-256 mismatch.' }
    $certificate=[System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $actualDerSha256 = [BitConverter]::ToString($sha256.ComputeHash($certificate.RawData)).Replace('-','').ToUpperInvariant()
    } finally { $sha256.Dispose() }
    if ($actualDerSha256 -ne $pinned) { throw 'SECURITY: parsed certificate DER SHA-256 mismatch.' }
    $thumb = $Thumbprint.Replace(' ','').ToUpperInvariant()
    if ($certificate.Thumbprint -ne $thumb) { throw 'Certificate thumbprint mismatch.' }
    if ($certificate.HasPrivateKey) { throw 'Refusing to handle a certificate that contains a private key. Only .cer public-leaf input is allowed.' }
    if ($certificate.Subject -ne 'CN=PeaZipModernMenuLocal' -or $certificate.Issuer -ne $certificate.Subject) {
        throw 'Unexpected community signing certificate subject or issuer.'
    }
    $eku=@($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' })
    if (-not $eku -or -not (([System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]$eku[0]).EnhancedKeyUsages | Where-Object { $_.Value -eq '1.3.6.1.5.5.7.3.3' })) {
        throw 'The certificate is not specifically a code-signing leaf.'
    }
    $basic=$certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' } | Select-Object -First 1
    if (-not $basic) { throw 'The certificate is missing basic constraints.' }
    if (([System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]$basic).CertificateAuthority) {
        throw 'Refusing to trust a CA certificate.'
    }
    $sha256ForStore=[System.Security.Cryptography.SHA256]::Create()
    $store='Cert:\LocalMachine\TrustedPeople'
    $record="HKLM:\SOFTWARE\PeaZipModernMenuCommunity\ManagedTrust\$thumb"
    if ($Action -eq 'Install') {
        if ($certificate.NotBefore -gt (Get-Date) -or $certificate.NotAfter -le (Get-Date)) { throw 'Certificate is not within its validity period.' }
        if (Test-Path "$store\$thumb") {
            $trustedCertificate = Get-Item -LiteralPath "$store\$thumb" -ErrorAction Stop
            $trustedHash = [BitConverter]::ToString($sha256ForStore.ComputeHash($trustedCertificate.RawData)).Replace('-','').ToUpperInvariant()
            if ($trustedHash -ne $pinned) { throw 'TrustedPeople already contains a different certificate at this SHA-1 locator.' }
            Log "Already trusted: $thumb (no ownership claim created)"
            exit 0
        }
        # Trust the EXACT X509Certificate2 object we already verified in memory.
        # Import-Certificate -FilePath would open the path a second time (TOCTOU window).
        $trustedStore = [System.Security.Cryptography.X509Certificates.X509Store]::new(
            [System.Security.Cryptography.X509Certificates.StoreName]::TrustedPeople,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
        $trustedStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        try { $trustedStore.Add($certificate) } finally { $trustedStore.Close() }
        try {
            New-Item -Path $record -Force -ErrorAction Stop | Out-Null
            New-ItemProperty -Path $record -Name 'InstalledBy' -Value 'PeaZip Modern Menu companion installer' -PropertyType String -Force -ErrorAction Stop | Out-Null
            New-ItemProperty -Path $record -Name 'CertificateSha256' -Value $pinned -PropertyType String -Force -ErrorAction Stop | Out-Null
        } catch {
            # If ownership registration fails, do not leave an unmanaged NEW trust grant.
            Remove-Item -LiteralPath "$store\$thumb" -Force -ErrorAction SilentlyContinue
            throw
        }
        Log "Imported public leaf cert to LocalMachine TrustedPeople: $thumb"
        exit 0
    }
    # Remove only installer-owned trust; do not break OTHER MSIX packages with same publisher.
    if (-not (Test-Path $record)) {
        Log "Certificate was not installed by our installer, preserving trust: $thumb"
        exit 0
    }
    $installedRecord = Get-ItemProperty -LiteralPath $record -ErrorAction Stop
    if ($installedRecord.CertificateSha256 -ne $pinned) {
        throw 'Certificate ownership record has no matching SHA-256 pin. Refusing automatic removal.'
    }
    $other=Get-AppxPackage -AllUsers -ErrorAction Stop |
        Where-Object { $_.Publisher -eq 'CN=PeaZipModernMenuLocal' } | Select-Object -First 1
    if ($other) {
        Log "Retained certificate: at least one MSIX with this publisher remains registered on this PC: $($other.PackageFullName)"
        exit 0
    }
    if (Test-Path "$store\$thumb") {
        $trustedCertificate = Get-Item -LiteralPath "$store\$thumb" -ErrorAction Stop
        $trustedHash = [BitConverter]::ToString($sha256ForStore.ComputeHash($trustedCertificate.RawData)).Replace('-','').ToUpperInvariant()
        if ($trustedHash -ne $pinned) { throw 'TrustedPeople certificate has a different SHA-256. Refusing removal.' }
        Remove-Item -LiteralPath "$store\$thumb" -Force -ErrorAction Stop
        Log "Removed installer-managed TrustedPeople certificate: $thumb"
    }
    Remove-Item -LiteralPath $record -Force -ErrorAction Stop
    exit 0
} catch {
    Log ('Certificate action failed: ' + $_.Exception.Message)
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

# Compile the per-user companion installer after Build-MSIX.ps1 succeeds.
[CmdletBinding()]
param([string]$IsccPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$msix = Join-Path $root 'out\PeaZip.ModernMenu.Community_1.2.2.0_x64.msix'
if (-not (Test-Path -LiteralPath $msix)) { throw 'MSIX not found. Run tools\Build-MSIX.ps1 first.' }
if (-not (Test-Path -LiteralPath (Join-Path $root 'out\PeaZipModernMenuCommunity.cer'))) {
    throw 'Missing public signing certificate. Build with -SignMode Community and -CertThumbprint. Development builds cannot be shipped with this installer.'
}
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
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $root 'out\PeaZipModernMenuCommunity.cer'))
$auth = Get-AuthenticodeSignature -LiteralPath $msix
if (-not $auth.SignerCertificate -or $auth.SignerCertificate.Thumbprint -ne $cert.Thumbprint) {
    throw 'MSIX signature does not match the exported community certificate. Inno Setup aborted.'
}
# Bind the exact public certificate and signed MSIX bytes to this particular installer.
# Replacing the .cer or .msix after compilation MUST fail before any UAC trust import.
$certPath = Join-Path $root 'out\PeaZipModernMenuCommunity.cer'
$certFileSHA = (Get-FileHash -LiteralPath $certPath -Algorithm SHA256).Hash.ToUpperInvariant()
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $certRawSHA = [BitConverter]::ToString($sha256.ComputeHash($cert.RawData)).Replace('-','').ToUpperInvariant()
} finally { $sha256.Dispose() }
if ($certFileSHA -ne $certRawSHA) {
    throw 'The .cer must contain exactly one binary DER certificate; PEM/extra bytes are refused.'
}
$msixSHA = (Get-FileHash -LiteralPath $msix -Algorithm SHA256).Hash.ToUpperInvariant()
$iss = Join-Path $root 'installer\PeaZip-ModernMenu.iss'
Write-Host ("Certificate pin (SHA-256 DER): $certRawSHA")
Write-Host ("MSIX pin (SHA-256 file):    $msixSHA")
& $IsccPath "-dExpectedCertSha256=$certRawSHA" "-dExpectedMsixSha256=$msixSHA" $iss
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
Write-Host ('Installer output: ' + (Join-Path $root 'out\installer\PeaZip-ModernMenu-Setup-v1.2.2.exe'))

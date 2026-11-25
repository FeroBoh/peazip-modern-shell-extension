# Read-only verification of v1.2.2 community release assets and installed payloads.
# Compatible with Windows PowerShell 5.1. Does NOT install, trust or delete certificates.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)] [string] $ProjectDir,
    [Parameter(Mandatory=$true)] [string] $ReleaseDir,
    [switch] $CheckInstalledFiles
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectDir).Path
$release = (Resolve-Path -LiteralPath $ReleaseDir).Path
$exeName = 'PeaZip-ModernMenu-Setup-v1.2.2.exe'
$cerName = 'PeaZipModernMenuCommunity.cer'
$msixName = 'PeaZip.ModernMenu.Community_1.2.2.0_x64.msix'
$exePath = Join-Path $release $exeName
$cerRelease = Join-Path $release $cerName
$sumPath = Join-Path $release 'SHA256SUMS.txt'
$cerBuild = Join-Path $project (Join-Path 'out' $cerName)
$msixBuild = Join-Path $project (Join-Path 'out' $msixName)
$installed = Join-Path $env:LOCALAPPDATA 'Programs\PeaZip Modern Menu'

function Assert-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing: $Path" }
}
function Hash-Of([string]$Path) {
    Assert-File $Path
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}
function Assert-SameHash([string]$One,[string]$Two,[string]$Label) {
    $a = Hash-Of $One
    $b = Hash-Of $Two
    if ($a -ne $b) { throw "HASH MISMATCH: $Label`n$One = $a`n$Two = $b" }
    Write-Host "PASS - $Label : $a" -ForegroundColor Green
}
function Raw-CertHash([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Cert.RawData)).Replace('-','') }
    finally { $sha.Dispose() }
}

# 1. Validate exact published release bytes against SHA256SUMS.txt
Assert-File $sumPath
$expected = @{}
foreach ($line in [System.IO.File]::ReadAllLines($sumPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -notmatch '^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$') {
        throw "Malformed SHA256SUMS.txt line: $line"
    }
    $name = $Matches[2].Trim()
    if ($expected.ContainsKey($name)) { throw "Duplicate SHA256SUMS entry: $name" }
    $expected[$name] = $Matches[1].ToUpperInvariant()
}
foreach ($name in @($exeName,$cerName)) {
    if (-not $expected.ContainsKey($name)) { throw "Missing hash line for $name" }
    $actual = Hash-Of (Join-Path $release $name)
    if ($actual -ne $expected[$name]) { throw "RELEASE HASH MISMATCH: $name" }
    Write-Host "PASS - release checksum $name : $actual" -ForegroundColor Green
}

# 2. Ensure exported community certificate is byte-identical to build version.
Assert-SameHash $cerRelease $cerBuild 'Release CER vs build CER'
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cerRelease)
$rawHash = (Raw-CertHash $cert).ToUpperInvariant()
$fileHash = Hash-Of $cerRelease
if ($rawHash -ne $fileHash) { throw 'CER is not a single DER certificate or contains additional bytes.' }
Write-Host "PASS - DER certificate SHA256 fingerprint: $rawHash" -ForegroundColor Green
Write-Host "INFO - Certificate SHA1 Thumbprint (not secret): $($cert.Thumbprint)"

# 3. Check signed MSIX build signer matches CER; warn if local trust chain is untrusted.
Assert-File $msixBuild
$signature = Get-AuthenticodeSignature -LiteralPath $msixBuild
if (-not $signature.SignerCertificate) { throw 'Signed MSIX has no signer certificate.' }
$signerHash = (Raw-CertHash $signature.SignerCertificate).ToUpperInvariant()
if ($signerHash -ne $rawHash) { throw 'SIGNED MSIX/CER CERTIFICATE MISMATCH.' }
Write-Host 'PASS - MSIX signer certificate matches release CER' -ForegroundColor Green
Write-Host "INFO - Build MSIX SHA256: $(Hash-Of $msixBuild)"
if ($signature.Status -eq 'Valid') {
    Write-Host 'PASS - MSIX signature trusted and valid for this machine' -ForegroundColor Green
} else {
    Write-Warning ("MSIX signature status is {0}; check signature independently with SignTool on a machine trusting this certificate. Not an indication that certificate and signature match is sufficient proof of authenticity." -f $signature.Status)
}

# 4. After installation, verify that payload copied from the actual Inno EXE equals build.
if ($CheckInstalledFiles) {
    $actualMsix = Join-Path $installed $msixName
    $actualCer = Join-Path $installed $cerName
    Assert-SameHash $actualMsix $msixBuild 'Installed MSIX vs build MSIX'
    Assert-SameHash $actualCer $cerBuild 'Installed CER vs build CER'
    $pkg = Get-AppxPackage -Name 'PeaZip.ModernMenu.Community' -ErrorAction Stop
    if (-not $pkg -or -not (@($pkg) | Where-Object { $_.Version.ToString() -eq '1.2.2.0' })) {
        throw 'Registered MSIX 1.2.2.0 not found for this user.'
    }
    Write-Host 'PASS - MSIX 1.2.2.0 registered for current user' -ForegroundColor Green
} else {
    Write-Host 'INFO - To compare installer-deployed files, re-run with -CheckInstalledFiles after installing this exact EXE.'
}
Write-Host 'Verification completed. The outer EXE itself is not CA-signed; checksum equality is not publisher authentication.'

# ONE-TIME action on the maintainer's build computer.
# The private key remains non-exportable in CurrentUser\My and is NEVER added to source/release.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$publisher = 'CN=PeaZipModernMenuLocal' # retained for upgrade identity compatibility with v1.2.x
Write-Host 'This creates a COMMUNITY SELF-SIGNED signing certificate, not a publicly trusted CA certificate.'
Write-Host 'Keep the same certificate for subsequent releases while it remains valid and secure.'
$answer = Read-Host 'Type CREATE to generate a new non-exportable private key'
if ($answer -cne 'CREATE') { throw 'Cancelled.' }
$cert = New-SelfSignedCertificate -Type Custom -Subject $publisher -KeyAlgorithm RSA -KeyLength 3072 `
    -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyExportPolicy NonExportable `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3','2.5.29.19={text}') `
    -NotAfter (Get-Date).AddYears(3) -CertStoreLocation 'Cert:\CurrentUser\My' `
    -FriendlyName 'PeaZip Modern Menu Community MSIX Signing'
Write-Host ('Certificate SHA1 thumbprint: ' + $cert.Thumbprint)
Write-Host 'Do not create a new certificate for every update. Save the thumbprint for the release build.'

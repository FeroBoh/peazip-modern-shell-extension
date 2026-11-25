"""Source-contract guards: installer pins exact SHA-256 public cert and signed MSIX.
Not a Windows installer runtime test; exercise the UAC and error paths in a clean VM.
"""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
iss=(r/'installer/PeaZip-ModernMenu.iss').read_text()
build=(r/'tools/Build-Inno.ps1').read_text()
install=(r/'tools/Install-Companion.ps1').read_text()
helper=(r/'tools/Trust-CompanionCertificate.ps1').read_text()
uninstall=(r/'tools/Uninstall-Companion.ps1').read_text()
assert '#ifndef ExpectedCertSha256' in iss and '#ifndef ExpectedMsixSha256' in iss
assert '-ExpectedCertSha256' in iss and '-ExpectedMsixSha256' in iss
assert 'Get-FileHash' in build and 'ComputeHash($cert.RawData)' in build
assert '"-dExpectedCertSha256=$certRawSHA"' in build and '"-dExpectedMsixSha256=$msixSHA"' in build
assert 'Get-FileHash' in install and 'ComputeHash($certificate.RawData)' in install
assert 'SECURITY: bundled .cer SHA-256' in install and 'SECURITY: bundled signed MSIX SHA-256' in install
assert '-ExpectedCertSha256' in install and '-ExpectedCertSha256' in uninstall
assert 'SECURITY: helper rejected certificate SHA-256 mismatch' in helper
assert 'CertificateSha256' in helper and 'CertificateAuthority' in helper
assert '$trustedStore.Add($certificate)' in helper and 'Import-Certificate -FilePath $CertificatePath' not in helper.split('$trustedStore.Add($certificate)')[0].split('# Trust the EXACT')[0]
assert 'Get-AppxPackage -AllUsers' in helper and 'ManagedTrust' in helper
assert r'Cert:\LocalMachine\TrustedPeople' in helper
assert ' -ExpectedCertSha256 ' in uninstall
print('PASS: exact SHA-256 certificate and MSIX pins, helper recheck, uninstall managed-trust bound')

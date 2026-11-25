"""Static guards for community trust opt-in. Actual UAC/MSIX behavior needs Windows tests."""
from pathlib import Path
from xml.etree import ElementTree as ET
import hashlib
import struct

r = Path(__file__).resolve().parents[1]
iss = (r/'installer/PeaZip-ModernMenu.iss').read_text()
install = (r/'tools/Install-Companion.ps1').read_text()
uninstall = (r/'tools/Uninstall-Companion.ps1').read_text()
trust = (r/'tools/Trust-CompanionCertificate.ps1').read_text()
build = (r/'tools/Build-MSIX.ps1').read_text()
assert '#define MyVersion "1.2.3"' in iss
assert 'ConsentBox.Checked := False;' in iss and 'NextButtonClick' in iss
assert 'Preinstall-Community.cer' in iss and 'Preinstall-Trust.ps1' in iss
assert '-AllowTrustImport' in iss and '-RemoveTrust' in iss
assert 'Get-AuthenticodeSignature' in install and 'SignerCertificate.Thumbprint' in install
assert 'Start-Process' in install and '-Verb RunAs' in install
assert 'TrustedPeople' in trust and 'Trusted Root' not in trust
assert "-Action Install" in install and "-Action Remove" in uninstall
assert 'Get-AppxPackage -AllUsers' in trust and 'ManagedTrust' in trust
assert "if (-not (Test-Path $record))" in trust
assert 'CertificateAuthority' in trust and '1.3.6.1.5.5.7.3.3' in trust
assert "'Community'" in build and "'1.2.3.0'" in build
assert 'PeaZipModernMenuCommunity.cer' in build
assert 'NonExportable' in (r/'tools/New-CommunitySigningCertificate.ps1').read_text()
assert not list(r.rglob('*.pfx'))
assert len(list((r/'screenshots').glob('*.png'))) == 8
for file,sz in [('Square44x44Logo.png',44),('Square150x150Logo.png',150),('StoreLogo.png',50)]:
    data=(r/'packaging/Assets'/file).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    assert struct.unpack(">II",data[16:24]) == (sz,sz)
print('PASS: user opt-in, UAC, self-signed leaf-only trust, ownership marker, and icon assets')

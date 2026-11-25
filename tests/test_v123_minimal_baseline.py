"""v1.2.3 minimal build guard, not a substitute for a Windows runtime test."""
from pathlib import Path
from xml.etree import ElementTree as ET
r = Path(__file__).resolve().parents[1]
install = (r/'tools/Install-Companion.ps1').read_text(encoding='utf-8')
cpp = (r/'src/PeaZipShellExtension.cpp').read_text(encoding='utf-8')
iss = (r/'installer/PeaZip-ModernMenu.iss').read_text(encoding='utf-8')
assert 'Add-AppxPackage @addArgs' in install
assert 'ForceTargetApplicationShutdown' in install
assert 'Get-AppxDefaultVolume' not in install
assert 'Get-AppxVolume' not in install
assert 'Set-AppxDefaultVolume' not in install
assert '$addArgs.Volume' not in install
assert 'PeaZipModernMenu.Staging' not in install
assert 'Get-AuthenticodeSignature' in install
assert 'ExpectedMsixSha256' in install and 'ExpectedCertSha256' in install
assert 'args.push_back(L"-add27z")' in cpp
assert 'args.push_back(L"-add2zip")' in cpp
assert 'args.push_back(L"-add2multi7z")' not in cpp
assert 'args.push_back(L"-add2multizip")' not in cpp
assert 'TaskDialogMsgBox' in iss and "['Yes', 'No']" in iss
assert 'CancelButtonClick' in iss
assert '#define MyVersion "1.2.3"' in iss
assert '#define MsixName "PeaZip.ModernMenu.Community_1.2.3.0_x64.msix"' in iss
xml = ET.parse(r/'packaging/AppxManifest.xml').getroot()
ns = {'m':'http://schemas.microsoft.com/appx/manifest/foundation/windows10'}
identity = xml.find('m:Identity',ns).attrib
assert identity['Name'] == 'PeaZip.ModernMenu.Community'
assert identity['Publisher'] == 'CN=PeaZipModernMenuLocal'
assert identity['Version'] == '1.2.3.0'
assert not list(r.glob('RELEASE_NOTES-v*.md'))
assert (r/'CHANGELOG.md').is_file()
print('PASS: v1.2.2 deployment baseline preserved; only minimal v1.2.3 changes')

"""Static regression checks for v1.2.1 installer/upgrade/uninstall maintenance.

Requires no Windows tooling. Real Windows deployment is still necessary.
"""
from pathlib import Path
import re
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
installer = (ROOT / 'installer/PeaZip-ModernMenu.iss').read_text(encoding='utf-8')
install = (ROOT / 'tools/Install-Companion.ps1').read_text(encoding='utf-8')
uninstall = (ROOT / 'tools/Uninstall-Companion.ps1').read_text(encoding='utf-8')
manifest = ET.parse(ROOT / 'packaging/AppxManifest.xml').getroot()
ns = '{http://schemas.microsoft.com/appx/manifest/foundation/windows10}'
identity = manifest.find(ns + 'Identity').attrib

assert identity['Name'] == 'PeaZip.ModernMenu.Community'
assert identity['Publisher'] == 'CN=PeaZipModernMenuLocal'
assert identity['Version'] == '1.2.1.0'
assert '#define MyVersion "1.2.1"' in installer
assert '#define MsixName "PeaZip.ModernMenu.Community_1.2.1.0_x64.msix"' in installer
assert 'ArchitecturesAllowed=x64os' in installer
assert 'PrivilegesRequired=lowest' in installer
assert 'PrepareToInstall' in installer and 'CurStepChanged' not in installer
assert re.search(r'PrepareToInstall.*?RunPS\(', installer, re.S)
assert all(installer.index('ExtractTemporaryFile(' + repr(k)) > 0 for k in
           ['Preinstall-Companion.msix', 'Preinstall-AppxManifest.xml', 'Preinstall-Companion.ps1'])
assert all(x in installer for x in ('CurUninstallStepChanged', 'usUninstall',
                                   'UninstallSilent', 'Abort;' ))
assert all(x in install for x in ('ForceTargetApplicationShutdown',
                                 'Add-AppxPackage @addArgs',
                                 'Downgrade refused', 'Publisher'))
assert 'Remove-AppxPackage' not in install  # updates are NEVER delete/reinstall
assert all(x in uninstall for x in ('Remove-AppxPackage',
                                   'Version -gt $maxVersion',
                                   'PeaZipModernMenu', 'if ($RemoveSettings)'))
assert 'AllUsers' not in uninstall  # never uninstall another user's app
assert uninstall.index('Remove-AppxPackage') < uninstall.index('if ($RemoveSettings)')
assert 'peazip.exe' not in installer.lower()
print('PASS: maintenance patch static invariants and safe upgrade/uninstall boundaries')

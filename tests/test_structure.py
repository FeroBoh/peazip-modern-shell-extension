"""Offline source-contract checks for v1.2.3. Not a substitute for Windows compilation/runtime tests."""
from pathlib import Path
import re
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CPP = (ROOT/'src'/'PeaZipShellExtension.cpp').read_text('utf-8')
GUI = (ROOT/'src'/'PeaZipMenuConfig.cpp').read_text('utf-8')
BUILD = (ROOT/'tools'/'Build-MSIX.ps1').read_text('utf-8')
ISS = (ROOT/'installer'/'PeaZip-ModernMenu.iss').read_text('utf-8')
INSTALL = (ROOT/'tools'/'Install-Companion.ps1').read_text('utf-8')
UNINSTALL = (ROOT/'tools'/'Uninstall-Companion.ps1').read_text('utf-8')
MANIFEST = ET.parse(ROOT/'packaging'/'AppxManifest.xml').getroot()
ns = {'m':'http://schemas.microsoft.com/appx/manifest/foundation/windows10',
      'd5':'http://schemas.microsoft.com/appx/manifest/desktop/windows10/5',
      'com':'http://schemas.microsoft.com/appx/manifest/com/windows10'}

CLSID = 'C8425781-09D3-4DEB-A947-30CD4509C7C4'
assert MANIFEST.find('m:Identity', ns).attrib['Version'] == '1.2.3.0'
assert MANIFEST.find('m:Identity', ns).attrib['Name'] == 'PeaZip.ModernMenu.Community'
assert MANIFEST.find('m:Identity', ns).attrib['Publisher'] == 'CN=PeaZipModernMenuLocal'
verbs = MANIFEST.findall('.//d5:Verb', ns)
assert len(verbs) == 2 and all(v.attrib['Clsid'] == CLSID for v in verbs)
classes = MANIFEST.findall('.//com:Class', ns)
assert len(classes) == 1 and classes[0].attrib['Id'] == CLSID
assert all(term in CPP for term in ('IExplorerCommand', 'IEnumExplorerCommand',
    'IShellItemArray', 'CreateProcessW', 'SIGDN_FILESYSPATH',
    'ECS_DISABLED', 'ECF_SEPARATORBEFORE'))
keys = ['ExtractDialog','ExtractHere','ExtractSmart','ExtractNewFolder','Test',
        'OpenAsArchive','BrowsePath','AddGUI','Add7Z','AddZIP','Encrypt7Z','Convert','HashTools']
assert len(keys) == len(set(keys)) == 13
for key in keys:
    assert f'L"{key}"' in CPP and f'L"{key}"' in GUI, key
assert len(re.findall(r'\{CommandId::\w+, L"\w+", L"[^"]+",', CPP)) == 13
assert len(re.findall(r'\{L"\w+", L"[^"]+", (?:true|false)\}', GUI)) == 13
assert all(x in CPP for x in ['-ext2main','-ext2herei','-ext2folderi',
      '-ext2newfolder','-ext2browseasarchive','-ext2browsepath','-add2archive',
      '-add27z','-add2zip','-add2multi7zencrypt','-add2multiconvert',
      'PEAUTILS','peazip_seven.icl'])
assert all(x in CPP for x in ['OrderedChildren()', 'CommandOrder', 'ShowSeparators',
                               'std::find(result.begin()', 'OrderedChildren())'])
assert all(x in GUI for x in ('CommandOrder', 'MoveSelected(-1)', 'MoveSelected(+1)',
                             'RenderList(0)', 'ID_RESTORE', 'ListView_SetCheckState',
                             'RegSetValueExW', 'PeaZipModernMenuConfigWindow'))
assert '__declspec(dllexport)' not in CPP
DEF = (ROOT/'src'/'PeaZipShellExtension.def').read_text('ascii')
assert 'DllGetClassObject PRIVATE' in DEF and 'DllCanUnloadNow PRIVATE' in DEF
assert all(x in BUILD for x in ('/DEF:$def','User32.lib','PeaZipMenuConfig.cpp',
                                'Comctl32.lib',"'1.2.3.0'", "'LocalTest','Community','Production','Unsigned'"))
assert 'DllCanUnloadNow' in CPP and 'DllGetClassObject' in CPP
assert all(x in INSTALL for x in ('Add-AppxPackage', 'Get-AppxPackage', 'ManifestPath',
                                '$existing.Version -gt $target', 'exit 1'))
assert all(x in UNINSTALL for x in ('Remove-AppxPackage', 'ManifestPath',
                                  'RemoveSettings', 'PeaZipModernMenu', 'exit 1'))
assert 'PrivilegesRequired=lowest' in ISS
assert 'CurUninstallStepChanged' in ISS and 'PrepareToInstall' in ISS
assert 'CurStepChanged' not in ISS  # MSIX registration before file copying, not after
assert all(x in ISS for x in ('ExtractTemporaryFile', 'Preinstall-Companion.msix',
    'Preinstall-Companion.ps1', 'Preinstall-AppxManifest.xml', 'Abort;',
    'UninstallSilent', 'ArchitecturesAllowed=x64os'))
assert 'ForceTargetApplicationShutdown' in INSTALL
assert 'PeaZipMenuConfig.exe' in ISS
assert 'PeaZip.ModernMenu.Community_1.2.3.0_x64.msix' in ISS
assert 'Remove-AppxPackage' not in ISS  # delegated to version-guarded script
assert 'peazip.exe' not in ISS.lower()    # no app core bundled
assert (ROOT/'tools'/'Build-Inno.ps1').is_file()
assets=ROOT/'packaging'/'Assets'
assert all((assets/f).is_file() for f in ('StoreLogo.png','Square150x150Logo.png','Square44x44Logo.png'))
print('PASS: v1.2.3 manifest, stable COM identity, 13 commands, order/config GUI, upgrade/uninstall scripts, packaging')

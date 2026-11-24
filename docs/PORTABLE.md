# Using PeaZip Portable

**Confirmed by the tester:** PeaZip Portable and the companion v1.2.1 worked together on a second Windows PC with no previous PeaZip installation. A path containing spaces and unusual path/drive-change cases are not yet separately verified.

The companion's shell DLL uses the configured `HKCU\Software\PeaZipModernMenu\ExecutablePath` first. If that path points to an existing file, it is passed to `CreateProcessW` along with the established PeaZip command-line switches. If no configured executable is found, the DLL checks the usual `%ProgramFiles%\PeaZip\peazip.exe` and `%ProgramFiles(x86)%\PeaZip\peazip.exe` locations.

## Configure

1. Download and extract the official **Windows x64** PeaZip Portable distribution from https://peazip.github.io/peazip-portable.html .
2. Place the folder at a durable location, for example `D:\PortableApps\PeaZip\`.
3. Install the companion on this Windows user account as described in the main README (the companion itself is **not** portable).
4. In **PeaZip Modern Menu — Configure menu**, click **Browse...** below **PeaZip executable** and choose `D:\PortableApps\PeaZip\peazip.exe`.
5. Save. Right-click on a test ZIP and check **Open as archive**, **Extract...**, and **Add to 7Z**.
6. If the Portable directory is moved or the drive letter changes, update the executable path and save again.

Alternate configuration from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Set-PeaZipPath.ps1 -PeaZipExe 'D:\PortableApps\PeaZip\peazip.exe'
```

## What remains portable?

PeaZip may run from the extracted directory without its own installer. However, the **modern shell extension is installed to Windows** via a per-user Inno Setup companion, a signed MSIX registration and a HKCU registry key. This necessarily leaves host-system integration. The official PeaZip documentation makes a similar distinction for Portable context-menu integration.

CLI behavior, icons (`res\share\icons\peazip_seven.icl`) and multi-selection should be checked against the particular Portable archive. A missing icon file falls back to the main executable icon. The command route does not introduce a dependency on PeaZip being installed through Inno Setup.

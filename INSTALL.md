# Install PeaZip Modern Shell Extension v1.2.3

**For regular Windows users. No compiling required.**

**Stable release:** v1.2.3. This guide covers the ready-made installer; developers can use [BUILDING.md](BUILDING.md).

## Before installing

- You need Windows 11 x64 and a separately installed or unpacked PeaZip (tested with PeaZip 11.4.0).
- Download the **`PeaZip-ModernMenu-Setup-v1.2.3.exe`** and **`SHA256SUMS.txt`** from the project's [official GitHub release page](https://github.com/FeroBoh/peazip-modern-shell-extension/releases/latest). You do **not** need to download a source ZIP to install the companion.
- The setup EXE is **not CA-signed**. The bundled MSIX is signed with a **self-signed community certificate**, not a publicly trusted publisher identity. You may see SmartScreen warnings. Check the source and make your own trust decision; do not bypass security warnings for an untrusted download.
- **Do not import an arbitrary `.cer` or install a private `.pfx` file.** The EXE includes the necessary public certificate and asks for explicit approval before adding trust.

## Check the download checksum

Open PowerShell in the folder where you downloaded the files:

```powershell
(Get-FileHash '.\PeaZip-ModernMenu-Setup-v1.2.3.exe' -Algorithm SHA256).Hash
Get-Content '.\SHA256SUMS.txt'
```

The 64-character SHA-256 digest must match the EXE line in `SHA256SUMS.txt`. If it does not match, **do not run the EXE**. This catches accidental changes but is **not proof of publisher identity** when both files come from the same untrusted source.

## Step-by-step installation

1. Run `PeaZip-ModernMenu-Setup-v1.2.3.exe` under your **normal Windows user account**. This is a **per-user** installer; do not use *Run as administrator* under a different account.
2. Read the page **Community signing certificate**. If you do not agree, choose to exit. Setup must stop without installing the extension or adding certificate trust.
3. If you agree, check the consent box and continue. If the public signing certificate is not already trusted, Windows may display an **administrator UAC prompt** for the certificate import. Declining UAC stops installation. Only the public code-signing leaf is added to `LocalMachine\TrustedPeople`, **not** Trusted Root. Trust may also apply to *other* packages signed with that same signing key.
4. After setup, verify the package if desired:

   ```powershell
   Get-AppxPackage -Name 'PeaZip.ModernMenu.Community' | Select-Object Name,Version,Status
   ```

   The expected version is `1.2.3.0`.
5. On some Windows 11 builds, enable **PeaZip Modern Menu** in **Settings → Personalization → Context menu → Application extensions**.
6. To customize the menu, launch **Start → PeaZip Modern Menu → Configure menu**. Save changes to show/hide/reorder commands. For PeaZip Portable, use **Browse** to select the portable `peazip.exe`.

## Upgrade from an earlier version

Run the newer Community Companion setup **under the same Windows account**. Save your work before upgrading because Windows may shut down the Explorer shell extension while updating the MSIX. Your command order and other settings are intended to be preserved. If you previously trusted a different test signing certificate, it may remain trusted until removed separately; the new installer does not silently revoke unrelated trust.

## Remove the entire companion

Windows may show **two separate entries** in Settings → Apps → Installed apps:

- **PeaZip Modern Menu** — the MSIX shell extension component.
- **PeaZip Modern Shell Extension – Community Companion** — the full Inno Setup installer/uninstaller.

**Always choose the _Community Companion_ entry for complete removal.** It removes the MSIX registration and companion files. Setup asks whether to preserve your menu preferences and whether to remove the **installer-managed** community certificate from TrustedPeople (subject to checks for other users and pre-existing trust). UAC may be required to revoke machine-wide trust.

Uninstalling only **PeaZip Modern Menu** leaves Inno companion files behind; re-running the Community Companion setup can repair the missing MSIX. The original PeaZip installation/portable files are unaffected.

## Additional notes

- **Per-user only:** system-wide install/provisioning for all Windows profiles is **not** available in v1.2.3.
- If Windows rejects installation, see `%TEMP%\PeaZipModernMenu-Install.log`; uninstall log is `%TEMP%\PeaZipModernMenu-Uninstall.log`.
- The EXE installer embeds MSIX/certificate SHA-256 values when it is built. The installed `.cer` and `.msix` can be compared with the publisher's original build; see the maintainer's [BUILDING.md](BUILDING.md) verification instructions.
- Keep in mind that a self-signed certificate is a local trust decision. Remove trust when you no longer need it; never disable UAC or SmartScreen just to install an untrusted app.

## Known MSIX limitation: non-system default AppX volume

On some Windows 11 installations, a **fresh** installation may fail during MSIX
registration if the Windows **default AppX/MSIX installation volume** is a
non-system drive such as `D:\WindowsApps` or `E:\WindowsApps`. This was
reproduced with the companion on one Windows 11 computer. It does **not** mean
that every Windows installation using D: or E: will fail.

**Check the current setting** in PowerShell:

```powershell
Get-AppxDefaultVolume | Select-Object PackageStorePath, IsSystemVolume
```

If a fresh installation fails and you decide to change this setting, open
**Windows PowerShell as Administrator** and set the Windows **system AppX
volume** as the default:

```powershell
$systemVolume = Get-AppxVolume | Where-Object { $_.IsSystemVolume -and -not $_.IsOffline }
Set-AppxDefaultVolume -Volume $systemVolume
Get-AppxDefaultVolume | Select-Object PackageStorePath, IsSystemVolume
```

For the tested PC, the expected system path was
`C:\Program Files\WindowsApps`. This setting depends on the actual Windows
system volume; do not hard-code the letter C: on other computers. Then retry
the Community Companion installer normally.

**Important:** `Set-AppxDefaultVolume` changes a **machine-wide default for
future AppX/MSIX installations**. It does not move already installed apps,
change your Desktop location, or delete an existing `D:\WindowsApps` folder.
The PeaZip companion does **not** change this setting automatically. If you
want your original default back **after a successful installation**, record
it before changing and restore it manually using the matching volume from
`Get-AppxVolume`. On the tested PC the installed companion continued to work
after restoring D: as the default. Do not move or delete WindowsApps folders,
modify their ACLs, or disable Windows security controls to bypass an error.

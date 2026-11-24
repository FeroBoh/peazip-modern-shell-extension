# Windows 11 26H2 validation plan — v1.2.1 maintenance candidate

**Observed test results (reported by a Windows 11 26H2 user):** v1.2.1 built with the x64 VS 2026 wrapper and Inno Setup 7.1.1, upgraded in place from v1.2.0.0, retained settings, executed commands, uninstalled, and reinstalled with settings restored. The tester also verified the companion and PeaZip Portable on a second PC without a prior PeaZip installation. This is not a production-signing or broad multi-device qualification test. The instructions below remain a repeatable regression matrix for new releases.

1. **Build:** in x64 VS 2026 Developer Command Prompt run `tools\Build-MSIX.ps1`, followed by `tools\Build-Inno.ps1`. Verify signature with `signtool verify /pa /v out\PeaZip.ModernMenu.Community_1.2.1.0_x64.msix`. Confirm COM exports `DllCanUnloadNow` and `DllGetClassObject` if desired.
2. **Current state:** do not uninstall 1.2.0.0. Confirm `Get-AppxPackage -Name PeaZip.ModernMenu.Community` returns version 1.2.0.0, status Ok. Export HKCU settings with `reg export HKCU\Software\PeaZipModernMenu "%USERPROFILE%\Desktop\PeaZipModernMenu-backup.reg" /y` in cmd.exe (or equivalent PowerShell).
3. **In-place update:** close Explorer windows and the configuration UI. Run the new Inno Setup EXE normally, NOT 'Run as administrator'. Watch whether it updates without 0x80073D02 or manually removing 1.2.0.0. This exercises `-ForceTargetApplicationShutdown` and `PrepareToInstall`.
4. **Verify update:** the MSIX must show 1.2.1.0 and Ok in `Get-AppxPackage`; check native configuration app still opens, saved command order appears, and the modern menu still performs extraction/add-to-archive. Windows might need re-enabling of Application extensions in Settings.
5. **Repeat:** run the same installer again; it should report the same MSIX version and not downgrade or create duplicate entries. If there is an older Inno uninstall log, ensure only one entry in Settings > Installed apps.
6. **Uninstall / preserve settings:** from Windows Settings > Installed apps uninstall PeaZip Modern Menu. Select **No** when asked whether to remove preferences. Check that `Get-AppxPackage -Name PeaZip.ModernMenu.Community` returns nothing; the PeaZip Modern Menu Start Menu shortcuts and its companion directory should disappear, but `HKCU\Software\PeaZipModernMenu` and original PeaZip 11.4.0 must remain.
7. **Reinstall:** install 1.2.1 again from the same EXE, verify custom menu order and command visibility restore without manual import.
8. **Uninstall / delete settings (optional):** uninstall again, this time choose **Yes** to remove settings; verify `HKCU\Software\PeaZipModernMenu` is absent after MSIX deregistration. Reinstall if you want to keep using the extension.
9. **Failure path (VM):** remove the test signing certificate's trust on an isolated test VM (not the main PC) and attempt install; expect a Preparing to Install failure **before** the native configuration EXE and shortcuts are copied. Also test a deliberately in-use shell extension and confirm the installer does not remove the working older MSIX on failure.
10. **Uninstall fault path (VM):** simulate an MSIX removal error, check log and uninstall result; in particular verify Inno's behavior regarding file cleanup. Do not claim unattended / atomic removal until this is confirmed on Windows.

### Useful verification commands (PowerShell)

```powershell
Get-AppxPackage -Name 'PeaZip.ModernMenu.Community' | Select-Object Name,Version,Status,InstallLocation
Get-ItemProperty -Path 'HKCU:\Software\PeaZipModernMenu' -ErrorAction SilentlyContinue |
  Select-Object CommandOrder,ShowSeparators
Get-Content "$env:TEMP\PeaZipModernMenu-Install.log" -Tail 25
Get-Content "$env:TEMP\PeaZipModernMenu-Uninstall.log" -Tail 25
```

**Release gate:** the user-reported upgrade/uninstall path passed. Public binary publication still requires production signing, no-test-certificate-trust deployment, extended Portable path/edge-case and fault-path tests as listed in `docs/RELEASE_CHECKLIST.md`. Never publish a developer private signing key.

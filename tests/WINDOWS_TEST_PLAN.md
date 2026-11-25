# New v1.2.2 SHA-256 pinning tests (clean disposable VM)

The compiled Inno Setup EXE embeds the exact expected **SHA-256** of the public DER certificate and signed MSIX.

1. Run `py -3 tests\test_certificate_pinning.py` and the other source tests.
2. On a clean Windows 11 VM without the companion key trusted, execute the EXE. Confirm the consent page shows the certificate SHA-256; decline and verify **no** MSIX registration or TrustedPeople import.
3. Accept but deny UAC; verify failed installation, no MSIX and no newly trusted certificate; review `%TEMP%\PeaZipModernMenu-Install.log`.
4. In a separate diagnostic build or by replacing an extracted temp `.cer` / `.msix` during test, verify a hash mismatch stops installation **before UAC**; never test by modifying a production installer's EXE.
5. Accept and approve UAC; verify `Cert:\LocalMachine\TrustedPeople\<SHA1>` contains only the pinned public leaf; check its SHA-256 with `Get-FileHash` against the build log. Verify `Get-AppxPackage` reports 1.2.2.0 and context-menu functionality.
6. Re-run setup with the same cert; no re-import should occur. Test upgrading a v1.2.1 test-cert signed MSIX to v1.2.2 with a **different** cert but the same Publisher, and inspect deployment logs.
7. Uninstall without removing trust and reinstall; then uninstall while consenting to remove installer-managed trust. Confirm only the matching SHA-256 marked as managed is removed and PeaZip itself remains.
8. If available, register the package for a second Windows account and verify that uninstall from the first account **retains** machine-wide trust. Test the manually pre-trusted leaf case: uninstall must not remove trust that was present before installation.
9. Document SmartScreen warnings, unsigned EXE limitations, and the fact that a local administrator retains full control of the machine trust store.

---

# v1.2.2 new signing workflow tests

See [docs/RELEASE_CHECKLIST.md](../docs/RELEASE_CHECKLIST.md) for the NEW consent, UAC, certificate-trust and update regression matrix. The tests below describe the previously verified v1.2.1 baseline and are intentionally preserved.

# Windows 11 26H2 validation plan — v1.2.1 maintenance candidate

**Observed test results (reported by a Windows 11 26H2 user):** v1.2.1 built with the x64 VS 2026 wrapper and Inno Setup 7.1.1, upgraded in place from v1.2.0.0, retained settings, executed commands, uninstalled, and reinstalled with settings restored. The tester also verified the companion and PeaZip Portable on a second PC without a prior PeaZip installation. This is not a production-signing or broad multi-device qualification test. The instructions below remain a repeatable regression matrix for new releases.

1. **Build:** in x64 VS 2026 Developer Command Prompt run `tools\Build-MSIX.ps1`, followed by `tools\Build-Inno.ps1`. Verify signature with `signtool verify /pa /v out\PeaZip.ModernMenu.Community_1.2.1.0_x64.msix`. Confirm COM exports `DllCanUnloadNow` and `DllGetClassObject` if desired.
2. **Current state:** do not uninstall 1.2.0.0. Confirm `Get-AppxPackage -Name PeaZip.ModernMenu.Community` returns version 1.2.0.0, status Ok. Export HKCU settings with `reg export HKCU\Software\PeaZipModernMenu "%USERPROFILE%\Desktop\PeaZipModernMenu-backup.reg" /y` in cmd.exe (or equivalent PowerShell).
3. **In-place update:** close Explorer windows and the configuration UI. Run the new Inno Setup EXE normally, NOT 'Run as administrator'. Watch whether it updates without 0x80073D02 or manually removing 1.2.0.0. This exercises `-ForceTargetApplicationShutdown` and `PrepareToInstall`.
4. **Verify update:** the MSIX must show 1.2.1.0 and Ok in `Get-AppxPackage`; check native configuration app still opens, saved command order appears, and the modern menu still performs extraction/add-to-archive. Windows might need re-enabling of Application extensions in Settings.
5. **Repeat:** run the same installer again; it should report the same MSIX version and not downgrade or create duplicate entries. If there is an older Inno uninstall log, expect **two different entries**, one for the MSIX and one for the Inno Setup Companion; verify they do not represent two copies of the same MSIX.
6. **Uninstall / preserve settings:** from Windows Settings > Installed apps uninstall **PeaZip Modern Shell Extension – Community Companion**, NOT the separate **PeaZip Modern Menu** MSIX entry. Select **No** when asked whether to remove preferences. Check that `Get-AppxPackage -Name PeaZip.ModernMenu.Community` returns nothing; the PeaZip Modern Menu Start Menu shortcuts and its companion directory should disappear, but `HKCU\Software\PeaZipModernMenu` and original PeaZip 11.4.0 must remain.
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

## Reported v1.2.2 results and remaining release gate (2026-11-25)

Tester reported: clean installation, functioning menu and immediate configuration
changes; in-place upgrade from v1.2.1; successful full companion uninstall with
optional removal/retention of installer-managed certificate trust. Refusing certificate
consent did not alter TrustedPeople. Two installed-apps entries were observed and
are **expected** for the current MSIX + Inno architecture.

**Still to confirm on a freshly rebuilt consent-dialog installer:** clicking Next
without consent displays an Exit Setup Yes/No question; Yes exits normally, No
returns to the consent page, neither causes trust or MSIX changes. Also test denial
of the UAC elevation on a clean machine, and verify certificate ownership and
cleanup after forced deployment failures. Never count an untested mode as passed.

**All users mode is not implemented** (see `docs/ALL_USERS_DEPLOYMENT.md`).

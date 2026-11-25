# v1.2.2 — release verification checklist

This separates **user-reported successful tests** from checks that still need explicit confirmation for the final EXE. Passing functional tests does not prove the absence of security bugs.

## Reported passed on Windows 11

- [x] MSVC x64, MSIX and Inno Setup build succeeded.
- [x] Source release contains eight requested screenshots and PeaZip branding assets.
- [x] Refusing certificate consent brings an exit-confirmation dialog; Yes exits, No allows returning to consent; no certificate imported when cancelled.
- [x] Declining administrator UAC stopped setup without registering MSIX or installing the certificate.
- [x] Approving certificate trust and installing MSIX succeeded.
- [x] Native context menu and PeaZip archive operations worked.
- [x] Dynamic visibility and command ordering worked immediately.
- [x] v1.2.1 to v1.2.2 update succeeded while retaining settings.
- [x] Uninstall removed MSIX and files and offered certificate removal or preservation.
- [x] Portable PeaZip was tested on a second computer (in earlier companion testing).

## Final binary release gate (perform on the exact EXE to be uploaded)

- [ ] Check EXE/CER SHA-256 hashes in `SHA256SUMS.txt` using `tools/Verify-Release-Bundle.ps1`.
- [ ] Confirm the signed build MSIX signer matches the exported CER and the package is signature-verified on a machine that trusts that certificate.
- [ ] Confirm persisted MSIX/CER from the installed **final release EXE** match the actual build MSIX/CER bytes (`-CheckInstalledFiles`).
- [ ] Confirm final EXE still has the latest consent UX and cancellation safety behavior after any final rebuild.
- [ ] Review release text for accurate self-signed/SmartScreen risk disclosure, per-user restriction and two Installed apps entries.
- [ ] Review copyright/trademark authorization for the PeaZip logo assets and applicable Inno Setup distribution terms.
- [ ] Confirm no private signing key or PFX was accidentally committed or attached.
- [ ] Review exact GitHub Release tag and uploaded file checksum after publication.

## Additional tests recommended, not claimed as passed

- [ ] Deliberately tamper with an extracted CER/MSIX and show that setup/elevated helper blocks it without trust changes (disposable VM).
- [ ] Repeat same-version install and an upgrade with Explorer holding the old COM DLL loaded.
- [ ] Test existing multiple Windows profiles and previously trusted certificate handling.
- [ ] Stress-test Unicode/long/UNC paths and unusually large multi-select batches.
- [ ] Test after Windows updates and on different Windows 11 builds.

**Known limitation:** `PeaZip Modern Menu` (MSIX) and `Community Companion` (Inno) may be listed as two installed applications. Remove the **Community Companion** entry for complete uninstall. System-wide installation is not supported in v1.2.2.

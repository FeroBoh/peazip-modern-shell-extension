# Changelog

All notable changes to **PeaZip Modern Shell Extension — Community Companion** are recorded here, newest first.
The corresponding section can be used as the description of each GitHub Release.

## [1.2.3] — Stable release (2026-11-25)

### Fixed

- **Add to ZIP** now uses `-add2zip`, and **Add to 7Z** uses `-add27z`,
  so all selected files and folders are passed to PeaZip together.
- Installer and uninstaller confirmation dialogs, including certificate
  consent refusal, Cancel and window close (X), use English **Yes / No**
  labels. Windows-owned dialogs such as UAC remain OS-localized.

### Compatibility and security

- Based on the verified **v1.2.2 stable** installer logic: unchanged per-user
  `Add-AppxPackage` behavior, SHA-256 pinning, explicit certificate consent,
  UAC elevation for trust, and certificate rollback on failure.
- MSIX version `1.2.3.0`; package identity, publisher, COM CLSID and
  authorized signing identity are preserved for upgrades.
- Experimental RC1–RC3 AppX `-Volume` selection and system-drive staging are
  **not** part of this stable source.
- Historical release notes are consolidated into this single `CHANGELOG.md`.

### Validation (maintainer-reported)

- Signed build and release files verified (EXE, CER, MSIX signer and installed
  MSIX/CER), no private signing key distributed.
- Clean install with the system AppX volume as default; v1.2.2 → v1.2.3
  upgrade retaining configuration and ordering.
- ZIP/7Z multi-selection and existing context-menu commands; English
  confirmation dialogs; refusal of certificate consent and UAC; complete
  uninstall with optional removal or retention of managed certificate trust.

### Known limitation

- On **some** Windows systems, fresh installation can fail when the **default
  AppX/MSIX installation volume** is a non-system drive (for example D: or E:).
  On the tested computer, changing the default to the system AppX volume C:
  allowed installation; the installed extension continued to work after the
  default was changed back to D:. The installer does **not** change the global
  default automatically. See [INSTALL.md](INSTALL.md#known-msix-limitation-non-system-default-appx-volume)
  for a manual administrator-approved workaround and its system-wide effects.
- The installer remains per-user; Windows can list separate MSIX and Inno
  Setup entries in Installed Apps. Use the **Community Companion** uninstaller
  for complete removal. The outer EXE is not signed by a publicly trusted CA.

## [1.2.2] — Stable release (2026-11-25)

### Added

- **Ready-to-use per-user Inno Setup installer** bundling the signed MSIX and its **public** self-signed community certificate. End users no longer need to build the extension themselves.
- Explicit, informed certificate-trust consent; declining consent offers to exit setup. Declining UAC stops installation.
- SHA-256 checks of the **exact** bundled certificate and signed MSIX, including re-verification by the elevated trust helper.
- Optional removal or retention of installer-managed certificate trust during uninstall.
- PeaZip visual branding for Windows/MSIX assets.
- `Verify-Release-Bundle.ps1` to check distribution checksums, MSIX signing certificate, and installed file identity.

### Verified during the release test cycle

- Clean installation, consent refusal, UAC refusal, command execution, GUI configuration and reordering, upgrade from v1.2.1, uninstall/reinstall, and certificate removal/retention.
- Release EXE matches the Inno Setup output, and installed MSIX/CER bytes match the corresponding signed build artifacts.

### Known limitations discovered afterward

- A clean install on a computer using a non-system D: AppX default failed during Windows MSIX registration (`0x800701C0`). A targeted candidate fix is tracked under v1.2.3; v1.2.2's published binary is unchanged.
- **Add to ZIP / Add to 7Z** may include only one file when multiple Explorer items are selected; targeted v1.2.3 fix pending validation. **Add to archive** was reported to work correctly with multi-selection.
- Windows may show two entries in Installed Apps, one for MSIX and one for Inno Setup. Use the **Community Companion** uninstaller for complete removal.
- Per-user only; the outer EXE is not signed by a publicly trusted certificate authority. The MSIX is signed by a self-signed community certificate.

## [1.2.1-rc1] — Public source pre-release (2026-11-24)

- Published source code, documentation and eight screenshots for review as an independent, unofficial PeaZip companion.
- Fixed the MSIX in-use upgrade error `0x80073D02` through `Add-AppxPackage -ForceTargetApplicationShutdown`.
- Preserved command selection and ordering across in-place updates; verified uninstall/reinstall behavior and PeaZip Portable support on a second Windows 11 PC.
- Fixed x64 MSVC build configuration and Inno Setup preprocessor syntax.
- **Source-first preview:** no ready-made publicly distributed installer in this release.

## [1.2.0] — Configuration GUI and ordering

- Added native Win32 configuration GUI with enable/disable, Move Up/Down, restore defaults and a custom `peazip.exe` path.
- Added per-user Inno Setup management, signed MSIX registration, and update/uninstall workflow.
- Retained the native cascading Explorer menu and PeaZip CLI actions.

## [1.1.x] — Initial proof of concept

- Created the native `IExplorerCommand` COM shell extension and MSIX registration model.
- Introduced core archive/extraction operations and per-user menu configuration.

---

**Security:** The project's self-signed MSIX certificate is not a publicly trusted identity. The EXE's SHA-256 hash proves byte-level consistency only; a checksum published alongside an EXE is not independent proof of publisher identity. Never publish the private signing key.

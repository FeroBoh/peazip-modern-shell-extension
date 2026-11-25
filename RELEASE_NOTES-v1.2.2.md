# PeaZip Modern Shell Extension v1.2.2 — Stable community installer

This version makes the independent PeaZip Windows 11 context-menu extension easier to install without developer tools. The C++ shell extension and PeaZip command behavior remain unchanged from the tested v1.2.1 release candidate.

## What's new

- Ready-to-use per-user **Inno Setup installer** bundling a signed MSIX and the **public** self-signed community certificate.
- Explicit, informed certificate-trust consent; refusing consent asks whether to exit, and refusal of UAC prevents installation.
- Exact SHA-256 pinning of the MSIX and certificate during setup, with revalidation by the elevated trust helper.
- Optional removal or preservation of installer-managed signing certificate trust during uninstall.
- PeaZip logo in the Windows app/MSIX branding assets.
- Configurable native context menu, command reordering, installed/portable PeaZip support and previous user settings retained.

## Verified on Windows 11 during the development cycle

Reported successful: clean install; refusal of certificate-trust consent; refusal of UAC import; MSIX registration and menu operations; command configuration and ordering; upgrade from v1.2.1 to v1.2.2; complete uninstall, certificate trust retention/removal and reinstall. Portable PeaZip was also verified on a second PC. These are project tests, not platform-wide certification.

## Download assets

- `PeaZip-ModernMenu-Setup-v1.2.2.exe` — ready-to-use Windows installer.
- `PeaZipModernMenuCommunity.cer` — **public certificate**, offered for independent inspection (the installer bundles this already).
- `SHA256SUMS.txt` — SHA-256 checksums for EXE and CER.
- Source code — generated automatically by GitHub from the tag.

See **[INSTALL.md](INSTALL.md)** (end users) or **[BUILDING.md](BUILDING.md)** (developers).

## Important security note

**The setup EXE is not signed by a publicly trusted code-signing authority.** The MSIX is signed by a self-signed community certificate. To install it, a Windows user must explicitly consent to trusting its public leaf in `LocalMachine\TrustedPeople`; administrator UAC may be requested. This trust decision can affect other packages signed by the same key. Setup pins the MSIX and certificate SHA-256 hashes, but neither hash pinning nor a checksum downloaded from the same place independently verifies publisher identity. Download only if you trust the project and its source.

## Known limitations

- **Per-user installation** only; all-users provisioning is not yet implemented.
- Windows may display two Installed apps entries for the MSIX component and Inno Setup manager. **Uninstall the Community Companion entry** for complete removal.
- The Windows built-in **Compress to** command is not removed.
- The extension is independently developed; PeaZip is installed separately and remains unmodified. PeaZip Portable can be selected by path; the companion itself is not portable.
- Additional adversarial tamper, multi-account and exotic-file-path tests are tracked in `docs/RELEASE_CHECKLIST.md` and should not be misrepresented as completed.

**No `.pfx`/`.p12` or private signing key is distributed.**

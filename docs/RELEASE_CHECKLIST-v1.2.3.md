# v1.2.3 stable — completed Windows release checklist

This source was rebuilt from v1.2.2 stable and does **not** contain AppX
volume switching or custom staging from experimental RC1/RC2/RC3.
All checked items below were **reported complete by the project maintainer/tester**.
They are not a claim of independent third-party security certification.

## Build and integrity (required before release)
- [x] Build signed MSIX 1.2.3.0 using the SAME authorized signing key as v1.2.2.
- [x] Build Inno Setup v1.2.3; run `Prepare-Binary-Release.ps1`.
- [x] Run `Verify-Release-Bundle.ps1` for EXE, CER and MSIX signature.
- [x] After installing exact candidate EXE, run `Verify-Release-Bundle.ps1 -CheckInstalledFiles`.
- [x] Check no private key, PFX or local build artifacts in GitHub sources or release assets.

## Windows runtime (required before release)
- [x] Clean install when Windows default AppX store is the system volume C:.
- [x] Upgrade from 1.2.2 to 1.2.3 preserves command order and settings.
- [x] Multi-select Add to ZIP archives ALL selected files/folders.
- [x] Multi-select Add to 7Z archives ALL selected files/folders.
- [x] Add to archive and other commands retain their previous behavior.
- [x] Consent declined: English Yes/No; no MSIX or new trust.
- [x] Cancel and X: English Yes/No; no partial installation.
- [x] Uninstall settings/trust questions: English Yes/No.
- [x] UAC denied: no new trusted cert and no partial install.
- [x] Complete uninstall; optional trust removal/retention.
- [x] Explain non-system AppX default limitation in INSTALL and release description (draft prepared for GitHub publication).

Notes: Windows UAC and Windows-controlled dialogs can remain OS-localized.
A clean install with default AppX D: or E: is NOT claimed as supported by
this release. Altering global AppX defaults is a separate informed
administrator choice; the installer must not do so automatically.

Release description text is provided separately for the GitHub Release; it is not a second per-version release-notes file in the repository.

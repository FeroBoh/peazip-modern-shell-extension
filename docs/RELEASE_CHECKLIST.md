# Publication checklist — v1.2.1 candidate

Status is based on **the tester's Windows 11 26H2 validation, including a second PC with PeaZip Portable**, not on broad device compatibility certification.

## Completed by the tester

- [x] Visual Studio 2026 x64 compilation and MSIX pack/sign succeeded.
- [x] Inno Setup 7 compiled after Pascal `#13#10` syntax correction.
- [x] Inno clean-install succeeded for v1.2.
- [x] v1.2.0.0 → v1.2.1.0 upgrade succeeded **without uninstalling first**.
- [x] Prior user configuration and command order survived upgrade.
- [x] Menu commands still ran after upgrade.
- [x] Normal Inno uninstall, clean reinstall, and preservation/restoration of settings succeeded.
- [x] Modern context menu reappeared and operated on reinstall.
- [x] PeaZip Portable plus the companion worked on a second PC with no prior PeaZip installation.
- [x] Original screenshots removed and replaced with exactly eight tester-provided screenshots (no duplicates).

## Required before posting **public binaries**

- [ ] Source review (especially COM input handling, malformed HKCU values, paths with quotes/unicode, long paths, selection limits).
- [ ] Additional PeaZip **Portable** regression with a path containing spaces, moved directory and changed drive letter (baseline Portable operation already passed).
- [ ] Fresh Windows profile/device without trusting the developer certificate, using production-trusted signing.
- [ ] Production signing **and timestamping** of MSIX and signing of outer Inno EXE.
- [ ] Verification that developer/test identity can be migrated safely to production identity.
- [ ] Repeated same-version install and silent install/uninstall on a test VM.
- [ ] Negative installation/uninstallation tests: certificate rejected, MSIX in use, uninstall failure, missing PeaZip.
- [ ] Multi-select with mixed files/folders, special characters, UNC paths and long filenames.
- [ ] License, ownership, copyright and **image assets** review, and Inno Setup compiler-license review.
- [ ] Confirm PeaZip 11.4.0 compatibility and test any other advertised versions.
- [ ] Sign and verify release asset checksum manifest; scan release executables.
- [ ] Create a GitHub repo, replace placeholder contributor attribution, review screenshots, create issue templates, clarify third-party status.

## Required before sending upstream

- [ ] Open an issue / discussion first, linking to this independent proof of concept.
- [ ] Link an English technical summary and screenshots; explain that PeaZip binaries are unaffected.
- [ ] Confirm upstream preferred licensing, integration mechanism and signing ownership.
- [ ] Only then prepare an upstream-focused PR if the maintainers want it.

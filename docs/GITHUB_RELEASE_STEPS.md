# GitHub publication steps (once release gates pass)

This source folder is **ready for a private review repository**. Do not publish signed installers or label the release production-ready until the release checklist is complete.

## 1. Create an independent repository

Pick an independent name, for example `peazip-modern-menu-companion`. The repository must **not** impersonate the official `peazip/PeaZip` project. A plain Git repository can be initialized from the unpacked ZIP:

```bat
git init
git add .
git commit -m "Prepare independent PeaZip Modern Menu v1.2.1 source candidate"
```

Create a remote repository using your GitHub account and push it. Do not commit the contents of `out/`, certificates, installer binaries, user-specific logs or personal identifiers.

## 2. Verify documentation and rights

- Replace the generic copyright placeholder in `LICENSE` with a confirmed, accurate attribution.
- Confirm rights for `packaging/Assets` and the eight tester-supplied PNG files in `screenshots/`. These are the only screenshots in the source archive; retain all eight without duplicate copies. Revise or remove any assets whose permissions are unresolved.
- Keep the project **unofficial** until the original maintainers accept any code.
- Make sure `docs/RELEASE_CHECKLIST.md` accurately reflects test evidence.

## 3. Source-only preview

An optional first release can be marked **pre-release / source preview** with the source ZIP. To create a reproducible source archive and a `.sha256` sidecar on any system with Python 3, run `python tools/Make-Source-Release.py` from the project root. Do not attach a developer-signed `.msix` or `.exe` as a publicly trusted installer. A source archive generated from this repository can be accompanied by a SHA-256 checksum file.

## 4. Production binary release (later)

After obtaining a suitable production signing identity, build with `-SignMode Production`, timestamp and verify the MSIX, sign and verify the outer setup EXE, and test on a clean device. Confirm migration from any dev package publisher to the new production publisher and re-run the complete install/uninstall matrix.

## 5. Contact PeaZip upstream

Review https://github.com/peazip/PeaZip/blob/sources/CONTRIBUTING.md and present the source-only prototype using `docs/UPSTREAM_PROPOSAL.md` as a starting draft. Ask if the maintainers would prefer an opt-in independently distributed companion or a different internal structure before opening a large pull request.

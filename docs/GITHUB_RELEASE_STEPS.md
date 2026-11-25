# Publishing v1.2.2 to GitHub (maintainer)

Keep the old `v1.2.1-rc1` tag and release unchanged.

## 1. Prepare repository source

Update the project source for v1.2.2 and include the new docs:

- `README.md` — overview and download link
- `INSTALL.md` — for regular users
- `BUILDING.md` — for developers and maintainers
- `RELEASE_NOTES-v1.2.2.md` — stable release text
- `tools/Verify-Release-Bundle.ps1` — read-only release integrity checks

Make sure the checked-in source contains no `out/`, generated installer binaries, developer certificates with private keys, `.pfx`, or secrets. Confirm the eight original screenshots are unchanged.

## 2. Verify and freeze tested binary artifacts

From the project root on the maintainer's Windows PC:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Verify-Release-Bundle.ps1 -ProjectDir . -ReleaseDir .\out\release-v1.2.2 -CheckInstalledFiles
```

Run the `-CheckInstalledFiles` check after an install of the **same final EXE** under the same user. If the EXE has changed (e.g. Inno UX code was edited), re-run `Build-Inno.ps1`, `Prepare-Binary-Release.ps1`, then the final install/verification sequence. Compare the published SHA256SUMS file against actual release bytes. Review `docs/RELEASE_CHECKLIST.md` for any remaining untested release gates; do not claim those were completed.

## 3. Publish new stable release

1. In GitHub Desktop, commit and push the v1.2.2 source changes to `main`.
2. In GitHub Releases create tag **`v1.2.2`** targeting the reviewed commit.
3. Title: **PeaZip Modern Shell Extension v1.2.2**; do **not** check *Pre-release*; mark as *Latest* if the option is offered.
4. Paste the content of `RELEASE_NOTES-v1.2.2.md` into the Release description.
5. Upload exactly the tested `PeaZip-ModernMenu-Setup-v1.2.2.exe`, `PeaZipModernMenuCommunity.cer` and `SHA256SUMS.txt` from `out\release-v1.2.2`.
6. GitHub automatically provides source ZIP/TAR archives. Do **not** upload `PFX`/private keys or PeaZip binaries.
7. Check the public release links, hashes, download text and installation instructions before announcing the release.

## 4. Upstream contact

Send Giorgio the new download link only after the binary release has been tested and published. Mention the optional self-signed trust model and how a regular user can install the companion without developer tools.

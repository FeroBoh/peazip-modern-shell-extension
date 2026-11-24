# Contributing

Thank you for improving this independent Windows 11 PeaZip companion.

- Start with a brief GitHub issue stating the Windows/PeaZip versions, reproducible steps and expected results.
- Prefer small changes. Keep the `IExplorerCommand` DLL separate from PeaZip itself; avoid bundling PeaZip source or executables.
- Preserve `HKCU` configuration and published command IDs/CLSID unless there is an explicit migration plan.
- For behavior changes, add a Windows manual test case and a lightweight offline regression check where practical.
- Run `python tests/test_structure.py`, `python tests/test_architecture_build.py`, `python tests/test_inno_preprocessor.py`, `python tests/test_maintenance_patch.py`, and `python tools/check_source_release.py` before submitting.
- Windows compiled/installer changes require x64 VS Build Tools, Windows SDK and Inno Setup validation. Please do not mark purely static tests as runtime proof.
- Do not commit generated `out/` files, MSIX, compiled `.exe`/`.dll`, PFX files, trusted certificates, private keys, tokens, personal paths or real usernames in logs/screenshots.
- Use the existing code style where possible. Document observed behavior distinctly from inferred compatibility.
- The project owner should settle contributor copyright attribution and downstream/upstream license compatibility before accepting external contributions for a public release.

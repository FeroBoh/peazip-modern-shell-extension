# PeaZip Modern Shell Extension — Community v1.2.1 (source release candidate)

This is an independent, unofficial Windows 11 Explorer menu extension for a separately obtained copy of PeaZip 11.4.0. No changes to the original PeaZip application or its installation are included.

## Highlights

- Native cascading PeaZip menu using `IExplorerCommand` and a packaged COM DLL.
- Original PeaZip CLI commands, icons and archive operations.
- Native C++ configuration interface with per-command toggles and user-adjustable ordering.
- Per-user Inno Setup management, including MSIX update and uninstall.
- Optional explicit executable path to an installed or Portable `peazip.exe`.

## Tests reported by the Windows 11 26H2 tester

- Built using Visual Studio 2026 x64 and Inno Setup 7.1.1.
- In-place MSIX upgrade from 1.2.0.0 to 1.2.1.0 succeeded, retaining preferences.
- Context menu and configured command ordering continued to work.
- Uninstall followed by reinstall restored the saved configuration and menu operation.
- PeaZip Portable plus the companion operated successfully on a second PC where PeaZip had not previously been installed.
- Documentation includes exactly eight tester-provided screenshots: context menus, classic-menu comparison, two configuration views, and Windows 11 26H2 context-menu settings.

## Distribution limitations

**Source-only preview candidate.** Production public MSIX/EXE signing, installation without local test-certificate trust, legal/asset provenance review and fault-path tests are still required. PeaZip Portable has been functionally tested on a second PC; path-with-spaces and extensive regression cases remain open. Do not distribute an installer signed with the local `PeaZipModernMenuLocal` development certificate as a public release.

See `docs/RELEASE_CHECKLIST.md` and `docs/GITHUB_RELEASE_STEPS.md`.

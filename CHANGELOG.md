# Changelog

## 1.2.1 — verified community release candidate (2026-11-24 status)

**User-tested on Windows 11 26H2 with PeaZip 11.4.0:**

- x64 Visual Studio 2026 build and Inno Setup 7.1.1 compilation succeeded after fixing the x86 toolchain mismatch and an Inno preprocessor `#13#10` syntax issue.
- In-place update from installed `1.2.0.0` to `1.2.1.0` succeeded with the `-ForceTargetApplicationShutdown` upgrade mechanism (the prior update attempt had failed with `0x80073D02`).
- Saved command visibility and order survived the upgrade; shell commands worked.
- Inno uninstall followed by reinstall worked; preferences were preserved and the menu was restored and functional.
- Source archive prepared for independent GitHub review with English documentation, source checks and publication gates.
- **No runtime functionality changes** in this GitHub-preparation snapshot: the actual COM DLL, configuration GUI, packaging manifest, and installed scripts remain the user-tested 1.2.1 code.

**Still pending:** portable executable runtime test, fresh-machine production-signed install, silent and negative/fault-path uninstalls, extended multi-selection, legal attribution/image-asset review.

## 1.2.1 — maintenance fixes

- `Add-AppxPackage -ForceTargetApplicationShutdown` when updating an existing package.
- Register MSIX in Inno Setup `PrepareToInstall` to prevent partial companion file installation on registration errors.
- Per-user uninstall with version/publisher guards; optional `HKCU` settings removal.
- Source-level x64 MSVC preflight and stale object cleanup; `Build-x64.cmd` convenience wrapper.
- Inno Pascal Script preprocessor fix: `#13#10` literals are kept within Pascal expressions.
- Package version `1.2.1.0`, installer version `1.2.1`.

## 1.2.0 — configuration UI and ordering

- Native Win32 settings GUI, enable/disable commands, Move Up/Down, restore defaults, separator settings, archive heuristics and explicit PeaZip executable path.
- Standalone per-user Inno companion installer, signed MSIX registration and update procedure.
- Original PeaZip CLI operations and cascading shell menu retained.

## 1.1.x — initial proof of concept

- Native `IExplorerCommand` DLL, MSIX registration and classic-style commands with icons.
- Functional menu and operations tested on Windows 11 26H2.

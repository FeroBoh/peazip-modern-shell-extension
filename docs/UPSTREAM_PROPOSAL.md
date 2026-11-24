# Proposed upstream discussion (draft — not sent)

**Subject:** Optional native Windows 11 Explorer context-menu companion for PeaZip (IExplorerCommand proof of concept)

Hello,

I have been testing an independent, open-source Windows 11 context-menu extension for PeaZip 11.4.0 and would like to share it for technical feedback, without assuming it belongs in the official repository.

The implementation is a small C++17 `IExplorerCommand` COM DLL registered by a companion MSIX package, plus a standalone Win32 configuration GUI and a per-user Inno Setup installer. It calls the existing PeaZip CLI; there are no changes to PeaZip's FreePascal/Lazarus core and no PeaZip binaries in the companion repository.

What it provides:

- A native cascading **PeaZip** submenu in the current Windows 11 Explorer menu, preserving the classic command set and icons.
- Configurable command visibility, command order and separators.
- Existing installed PeaZip integration and an explicitly configurable path for PeaZip Portable.
- Install, in-place upgrade and uninstall with per-user settings preservation.

On Windows 11 26H2, the menu operations, an in-place 1.2.0.0 → 1.2.1.0 MSIX update, and an uninstall/reinstall cycle worked as intended. PeaZip Portable also worked with this companion on a second PC without a prior PeaZip installation. Publicly trusted distribution signing and broader regression tests remain outstanding.

I understand that Windows Shell COM integration adds build, signing and maintenance complexity. I would be interested in your feedback on whether a separately maintained, opt-in community companion would be useful, and whether you would prefer an alternate packaging approach for possible upstream integration.

Source and documentation: [insert GitHub repository URL once published]

Thank you for considering it.

---

**Submission notes:** Review the current PeaZip [contribution guidelines](https://github.com/peazip/PeaZip/blob/sources/CONTRIBUTING.md). Prefer an issue/discussion or direct inquiry **before** an unsolicited large PR; avoid claiming affiliation. The maintainers explicitly mention Windows context-menu and system-integration contributions as a possible area of work.

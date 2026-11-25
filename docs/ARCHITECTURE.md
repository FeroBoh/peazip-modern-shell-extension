# Architecture / design constraints

```text
Windows 11 Explorer
  └─ packaged COM activation (IExplorerCommand / IEnumExplorerCommand)
      └─ PeaZip.ModernShellExtension.dll (MSIX)
          ├─ HKCU\Software\PeaZipModernMenu (visibility, order, EXE path)
          ├─ Windows shell file selection (IShellItemArray)
          └─ CreateProcessW("...\peazip.exe", CLI switches + selected paths)
                 └─ independent installed OR Portable PeaZip

Inno Setup (per user)
  ├─ prepares / updates signed MSIX with PowerShell Add-AppxPackage
  ├─ installs configuration GUI and uninstall entries
  └─ removes matching per-user MSIX before uninstalling companion files
```

The package manifest registers the COM CLSID `C8425781-09D3-4DEB-A947-30CD4509C7C4` and a `windows.fileExplorerContextMenus` entry for files and directories. **This is a separately packaged companion**, not a conversion of the PeaZip application itself to MSIX and not a sparse/external-location package.

### Configuration

The native GUI writes the following under `HKCU\Software\PeaZipModernMenu`:

- `ExecutablePath` (`REG_SZ`), optional explicit location for an installed or Portable `peazip.exe`.
- `CommandOrder` (`REG_SZ`), semicolon-separated stable command identifiers.
- `ShowSeparators`, `DetectArchives` (`REG_DWORD`).
- `Commands\<CommandKey>` (`REG_DWORD` 0/1), command visibility.

The DLL reads settings on menu construction. Unknown/duplicate `CommandOrder` entries are ignored and missing entries are appended in classic order. Group separators are generated at boundaries between adjacent *visible* command categories.

### Launch and safety

The shell DLL collects filesystem paths from `IShellItemArray` (virtual shell items unsupported) and invokes PeaZip using `CreateProcessW`. It quotes arguments rather than running via a shell command interpreter. It avoids opening archives on the Explorer UI thread. The source limits a single selection to 4096 items; command-line length constraints can become active before that limit for sufficiently long paths. This is **not a promise of unlimited multi-selection**, and handling should be revalidated in a broader QA matrix.

Extraction operations can be disabled for file types not recognized by an extension heuristic. **The heuristic does not inspect the archive content**; PeaZip handles validity and actual extraction.

Icons are referenced dynamically from the existing PeaZip tree; this source package does not redistribute PeaZip's ICL icon library.

### Identity and upgrade path

The developer/test MSIX currently has:

```text
Name:      PeaZip.ModernMenu.Community
Version:   1.2.3.0
Publisher: CN=PeaZipModernMenuLocal
```

An Inno Setup update of the **same identity** and higher version triggers MSIX update under the current Windows user. The script uses `-ForceTargetApplicationShutdown` if an older package is installed. The user verified an in-place `1.2.0.0 → 1.2.1.0` update, preserving settings.

**Changing the publisher certificate subject changes the MSIX identity/family.** An eventual public certificate with a different subject is not a transparent in-place upgrade from this test identity. Plan a one-time transition and avoid conflicting COM registrations.

### Open questions for maintainers

- Does upstream prefer the current self-contained MSIX companion, or packaging with external location (sparse MSIX)?
- How should configuration share UX with PeaZip's existing system integration settings?
- Who will hold the public signing identity and maintain Windows build/test infrastructure?
- Which versions of Windows 11 and PeaZip should be officially supported?

Neither PeaZip core nor the old/classic registry integration is modified by the companion.

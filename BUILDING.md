# Build and verify from source (developers / maintainers)

**Regular users: use [INSTALL.md](INSTALL.md) and the published EXE. No development tools are needed.**

## Prerequisites

- Windows 11 x64, Visual Studio 2022/2026 C++ Build Tools (x64) and Windows SDK.
- Inno Setup 6 or 7 to produce the EXE installer.
- Windows PowerShell 5.1+ for build scripts; Python 3 to run optional static checks.
- A separate installed or portable PeaZip 11.4.0 for functional testing.

## Build the signed MSIX and Inno Setup executable

On the **maintainer's trusted development PC**, create a dedicated self-signed code-signing certificate **once** (not for every version):

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\New-CommunitySigningCertificate.ps1
```

Record the printed SHA-1 thumbprint as the identifier for the local certificate store. This **thumbprint is not a secret**; the **private signing key is secret** and must never be distributed. Reuse the same authorized signing identity for compatible upgrades.

Build with x64 tools:

```bat
tools\Build-x64.cmd -SignMode Community -CertThumbprint YOUR_CERT_THUMBPRINT
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Inno.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-Binary-Release.ps1
```

Expected output:

```text
out\PeaZip.ModernMenu.Community_1.2.2.0_x64.msix
out\PeaZipModernMenuCommunity.cer
out\installer\PeaZip-ModernMenu-Setup-v1.2.2.exe
out\release-v1.2.2\PeaZip-ModernMenu-Setup-v1.2.2.exe
out\release-v1.2.2\PeaZipModernMenuCommunity.cer
out\release-v1.2.2\SHA256SUMS.txt
```

**How the exact payload is pinned:** `tools/Build-Inno.ps1` checks that the MSIX signer matches the exported public `.cer`, computes the SHA-256 of the signed MSIX and of the certificate's DER bytes, and embeds those two hashes into the Inno Setup binary as `ExpectedMsixSha256` and `ExpectedCertSha256`. The Inno setup source includes the `.msix` and `.cer` under `[Files]` both for preregistration and as companion assets. At installation time the helper checks the payload hashes before asking for trust, and the elevated helper rechecks the certificate. This is a **content-integrity safeguard**, not public CA attestation of the outer setup EXE.

## Verify the final release files and installed payloads

Before uploading anything:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Verify-Release-Bundle.ps1 -ProjectDir . -ReleaseDir .\out\release-v1.2.2
```

That script validates the published EXE and CER against `SHA256SUMS.txt`, checks the cert's SHA-256 fingerprint, checks that the signed MSIX signer certificate matches the `.cer` and verifies that the staged CER equals the build CER. Use `signtool verify /pa /v <path-to-msix>` on a Windows machine that trusts the signing certificate to validate its signature chain; a clean machine without that trust may report an untrusted signer.

For a stronger end-to-end check **after running the exact release EXE on a test VM**, compare what the installer persisted:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Verify-Release-Bundle.ps1 -ProjectDir . -ReleaseDir .\out\release-v1.2.2 -CheckInstalledFiles
```

The installed MSIX and public CER must hash-identically match the original signed MSIX and certificate in `out/`. The Inno setup file table and mandatory build-time pins are the link between those source payloads and the EXE. **Without extracting the Inno Setup 7 package or running the installer, the EXE's outer SHA-256 alone cannot show its internal MSIX/CER contents.** Do not claim otherwise.

The verification script is read-only; it does not install, import or delete any certificate.

## Static source checks

```bat
py -3 tests\test_structure.py
py -3 tests\test_architecture_build.py
py -3 tests\test_inno_preprocessor.py
py -3 tests\test_maintenance_patch.py
py -3 tests\test_community_distribution.py
py -3 tests\test_certificate_pinning.py
py -3 tools\check_source_release.py
```

These checks do not replace compilation or Windows runtime tests. Do not commit `out/`, any `.pfx`/`.p12`, exported private keys or generated install-time logs. Consult [signing and distribution](docs/SIGNING_AND_DISTRIBUTION.md) for detailed signing limitations.

## Release policy

- Stage only the final, actually tested EXE, corresponding public `.cer` and `SHA256SUMS.txt` in a GitHub Release; GitHub automatically generates source archives for the tag.
- Do not regenerate or re-sign the MSIX after the final Inno EXE is compiled: the pinned hashes would change. If you rebuild, **repeat the verification and test**.
- The binary installer is self-signed at the MSIX layer and not publicly CA-signed as an EXE. Carefully explain certificate trust, UAC, SmartScreen, two Installed apps entries, and the per-user restriction in the Release notes.
- Preserve the tested `v1.2.1-rc1` historic release; publish v1.2.2 under a **new** tag after review.
- Verify rights to package icons/PeaZip branding and applicable Inno Setup license terms before wider binary distribution.

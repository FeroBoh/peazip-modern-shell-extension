# Signing and distribution policy

**Do not publish a development-signed installer as a trusted official release.**

## Existing development build

`Build-MSIX.ps1` defaults to `LocalTest`, which creates or reuses a self-signed certificate with subject `CN=PeaZipModernMenuLocal` in `Cert:\CurrentUser\My` and signs the test MSIX. Exported `.cer` files contain a **public certificate**, not a private key; nevertheless, exclude these test trust anchors from a public source/release ZIP to avoid confusing users.

The Inno Setup installer explicitly does **not** install arbitrary trust roots or bypass Windows' deployment checks. A fresh machine without the locally trusted certificate will reject this test MSIX. This is intentional.

## Production signing

1. Agree on the maintainer / legal publisher identity. Obtain a code-signing certificate trusted by the target Windows devices, or use Microsoft's Artifact Signing service (and timestamp signing). **Never commit PFX/P12 files, private keys, credential files, personal tokens or certificate passwords**.
2. Use `tools\Build-x64.cmd -SignMode Production -CertThumbprint <sha1-thumbprint> [-CertStore CurrentUser|LocalMachine] -TimestampUrl <rfc3161-url>` with a supported signing setup. `Build-MSIX.ps1` updates the manifest publisher to the certificate's actual Subject.
3. Verify the generated MSIX signature, identity/publisher and expiry/timestamp with `signtool verify /pa /v` on a clean test machine.
4. Configure a signing step for the **outer Inno Setup EXE** too. The current Inno Setup script does **not** automatically sign its own output. Do not label the EXE 'official' or 'trusted' until signed and verified.
5. Run clean-machine tests on a Windows profile which never trusted the local development certificate.
6. Perform an intentional migration plan from developer publisher to the chosen production publisher; these package families cannot be silently treated as the same MSIX update.
7. Publish SHA-256 checksums of release assets and review/update certificate-renewal and timestamping policy.

The `LocalTest` mode must not be used in a public binary release, and `Unsigned` mode is useful for build inspection only (Windows normally refuses unsigned MSIX deployment).

## Additional notes

- Inno Setup 7 has commercial-use licensing conditions; consult its official terms before using the compiler in a commercial setting. This repository **does not embed Inno Setup**.
- Package identity, shell registration and app-extension enablement settings may be cached by Windows Explorer; upgrade instructions must communicate that Windows may terminate Explorer/COM host processes.
- Updating binaries during existing sessions is supported through `Add-AppxPackage -ForceTargetApplicationShutdown`, but unattended deploys, reboots and error recovery need separate tests.
- Keep test trust certificates installed on test environments only. Removing an actively used certificate without a recovery plan will prevent updates.

Microsoft references: https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide and https://learn.microsoft.com/en-us/windows/msix/msix-troubleshooting-guide

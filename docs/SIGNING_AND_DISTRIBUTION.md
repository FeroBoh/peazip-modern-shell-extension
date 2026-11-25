# Signing and distribution: v1.2.2 community installer

This project is **not a CA-signed or Microsoft Store release**. This plan provides a transparent, consent-based *self-signed* community distribution for advanced users who explicitly trust the publisher and understand the risk.

## Why not generate a certificate on each user's PC?

The MSIX must already be signed before it can be installed. A newly created certificate on a client PC cannot sign the supplied MSIX without a signing utility such as the Windows SDK SignTool, which is **not** generally present and is not automatically redistributable. Generating a new client key on every upgrade also breaks repeatable trust, complicates renewal and adds avoidable risk. Use one dedicated maintainer-side signing key for successive releases.

## First community signing build (maintainer PC)

**Preserving identity:** The publisher stays `CN=PeaZipModernMenuLocal` for compatibility with earlier packages. This legacy publisher name does **not** mean the key is automatically trusted.

1. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\New-CommunitySigningCertificate.ps1` **once**, then safely record the SHA-1 thumbprint printed. The non-exportable private key remains in `Cert:\CurrentUser\My` on the build PC. If an existing matching cert is being reused intentionally, do not generate another.
2. `tools\Build-x64.cmd -SignMode Community -CertThumbprint <THUMBPRINT>`.
3. `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Inno.ps1`.
4. The source build produces `out\PeaZip.ModernMenu.Community_1.2.2.0_x64.msix`, `out\PeaZipModernMenuCommunity.cer` (PUBLIC ONLY), and `out\installer\PeaZip-ModernMenu-Setup-v1.2.2.exe`.
5. Verify signatures with SignTool and test *the exact installer* on a clean Windows 11 x64 VM with no pre-trusted signing certificate before publishing. Test consent refusal, refusal of UAC, successful import, update from 1.2.1, uninstall cert cleanup, and another Windows user who still needs the package.
6. Release `Setup.exe` and public `.cer` (optional transparency artifact), plus SHA-256 checksums. **Never publish `.pfx`, `.key`, signing credentials, or copy the private key**. Do not bundle Windows SDK SignTool.

IMPORTANT: Selecting a NEW certificate while preserving the same Publisher is still a signing-key change. Test in-place MSIX updates against earlier keys. If incompatible, document a manual migration rather than silently uninstalling an older release.

## SHA-256 binding of a release installer

`tools/Build-Inno.ps1` calculates the SHA-256 of the exported public DER `.cer` and of the FINAL signed `.msix`, then embeds **both expected 64-character hashes in the compiled Inno Setup EXE**. Building the `.iss` directly without these compiler definitions is rejected.

At install time, BEFORE any UAC elevation or certificate import, `Install-Companion.ps1` compares the extracted certificate's file SHA-256 **and** its parsed DER SHA-256 to the pinned value, and compares the signed MSIX file SHA-256 to its own pin. The signer identity in the MSIX is also compared to that exact certificate. The elevated `Trust-CompanionCertificate.ps1` independently rechecks the certificate SHA-256, rejects CA certificates, requires the Code Signing EKU, and imports the already-verified in-memory certificate object (not a fresh read of the file). Before removing any managed trust entry, it also checks that the currently installed certificate has the pinned SHA-256. A SHA-1 Windows certificate thumbprint is still used as the certificate *store locator*; it is NOT used as the security pin.

During uninstall, only a certificate marked as installed by this companion, with the exact same recorded SHA-256, is eligible for removal. The helper refuses automatic cleanup when any Windows account still has an MSIX package with the same publisher, or when the trust was already present before this installer ran. To avoid race conditions, do not change the certificate file or extracted installers while installation is in progress.

**Important:** A compiled-in fingerprint protects against accidental certificate/package substitution after the installer is built; it does **not** make an unsigned Inno Setup EXE a trusted publisher. The EXE and checksum must still be obtained from a trusted channel, and a local administrator can always modify the machine trust store.

## Transparent trust

The installer requires an unchecked opt-in checkbox before any MSIX installation. With permission, an elevated helper imports only the code-signing leaf into `LocalMachine\TrustedPeople`. It records whether **this installer** imported it, so uninstall does not remove unrelated/pre-existing trust. Package registration still runs as the user who invoked the installer.

TrustedPeople is NOT Trusted Root Certification Authorities. A self-signed signing certificate is nevertheless a powerful trust grant: Windows may accept other packages signed by that same key. The installer cannot prove its own origin because its EXE is not CA-signed. Tell users to obtain it from the known GitHub release and verify checksums. No silent trust import or bypass of Windows signature validation.

## Uninstall limits

The public cert can be removed by the elevated helper only if the installer had imported it and no Windows account still has this package registered. A cert trusted manually before installation is left alone. Uninstall asks for consent before trying the removal. Machine-wide trust may affect more than one account; the helper errs on the side of retaining trust when there is a detected dependency. Installation also attempts rollback of newly imported trust if deployment fails, but UAC cancellation can prevent this cleanup; the log explains manual remediation.

## Windows/Microsoft sources

- https://learn.microsoft.com/en-us/windows/msix/msix-troubleshooting-guide
- https://learn.microsoft.com/en-us/windows/msix/package/create-certificate-package-signing
- https://learn.microsoft.com/en-us/windows/apps/dev-tools/winapp-cli/security
- https://learn.microsoft.com/en-us/windows/desktop/seccrypto/signtool

## Release artifact staging

After successfully building and testing the Inno installer, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-Binary-Release.ps1`. Only the public `.cer` and installer EXE, plus `SHA256SUMS.txt`, will be copied to `out\release-v1.2.2`. Never attach the builder's private key or PFX to GitHub.

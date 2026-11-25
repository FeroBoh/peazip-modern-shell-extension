# Proposal: machine-wide deployment (not implemented in v1.2.2)

Status: **design only**. The official v1.2.2 installer is per-user. This document
must **not** be interpreted as a tested installer mode or an instruction to run
administrative provisioning on a production device.

## Candidate implementation

An administrative install could trust only the verified, build-pinned public signing
leaf in `LocalMachine\TrustedPeople`, and provision the signed MSIX using Windows
DISM (`Add-AppxProvisionedPackage -Online` with a correctly signed and licensed
package). Microsoft documents that provisioned apps are registered for new accounts
at first logon and for existing accounts at their next logon. Existing active users
should be signed out during deployment; provisioning is not equivalent to installing
under each currently active account instantaneously.

A multi-user-aware Inno Setup mode would need a program-files (machine) installation,
privilege elevation, a resilient, machine-wide uninstall manager, and independent
per-user settings in `HKCU\Software\PeaZipModernMenu`. It must not execute the
per-user `Add-AppxPackage` routine under an elevated *different* account. Each Windows
11 account may also need to enable the shell extension in its Context menu settings.

## Critical uninstall and update details

Removing provisioning with `Remove-AppxProvisionedPackage -Online` stops future user
registrations but does **not** automatically remove the extension from existing
profiles. Existing registrations may require administrative
`Remove-AppxPackage -AllUsers` after the correct package is identified. Windows
can require the Explorer/COM host to close. All-user updates require account-aware
coordination and tests on multiple accounts, including accounts that have not logged
in since initial installation.

Machine-level signing trust should be revoked **only** after confirmation that no
matching packages still depend on it and that the companion originally installed
that exact SHA-256-pinned certificate. No trust or package belonging to PeaZip itself
may be changed.

## Prerequisites for a future release

- Two or more local test accounts, one existing and one created after provisioning
- Tested elevation and consent, including refusal and partial failure rollback
- Verified use of the Portable PeaZip path from each account
- Successful upgrade, full uninstall and trust cleanup across all accounts
- User-facing documentation explaining differing Windows UI and app settings

Relevant Microsoft documentation:

- https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/sideload-apps-with-dism-s14?view=windows-11
- https://learn.microsoft.com/en-us/powershell/module/dism/remove-appxprovisionedpackage
- https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage

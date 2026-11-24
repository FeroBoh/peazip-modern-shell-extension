# Security policy

This is a **community proof of concept**, not an official PeaZip package and not a security-supported product. There is currently no public binary distribution or guaranteed response SLA.

Please avoid publishing credentials, signing keys, private certificates, personal paths or Windows account identifiers in bug reports. If you find a vulnerability, contact the repository maintainer privately once a contact method has been defined; if no contact is yet available, avoid sharing sensitive proof-of-concept material publicly.

Threat boundaries: Explorer loads a COM shell command into a shell host; the DLL receives selected filesystem paths and starts a separately installed `peazip.exe`. Public binary releases require code signing, command-line argument handling review, dependency review and fresh-machine testing. The test certificate is not a root of public trust.

Recommended release practice: maintain signed release artifacts, verify SHA-256 checksums and do not run installer packages from untrusted sources.

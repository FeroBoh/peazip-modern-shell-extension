# Source provenance, licenses, and acknowledgements

## Independent companion

PeaZip Modern Shell Extension is an **unofficial, independently developed community companion** for Windows 11. Its own source files include C++/Win32 code, PowerShell scripts, Inno Setup scripts, documentation, tests, and packaging assets. The companion's source and documentation are offered under the MIT License in the repository's [`LICENSE`](../LICENSE), to the extent that the project's contributors hold the necessary rights.

The current MIT copyright notice uses the collective name **PeaZip Modern Shell Extension contributors**. The repository publisher should confirm that the notice accurately reflects those entitled to license the contributed code and assets; if needed, add appropriate individual credit or a `CONTRIBUTORS.md` file before release. This project does not claim rights in third-party material.

## PeaZip and icons

[PeaZip](https://github.com/peazip/PeaZip) is developed by Giorgio Tani and is distributed separately under **LGPL-3.0**. This companion does **not** bundle or redistribute the PeaZip executable, archive backends, or PeaZip's context-menu icon files. It invokes the PeaZip command-line interface and uses menu icon resources from the user's own installed or unpacked PeaZip instance at runtime. PeaZip code, icons, names, and other protected material remain subject to their respective licenses and rights.

The three images under `packaging/Assets` are package identity images. In v1.2.2 they contain resized versions of the supplied PeaZip logo, rather than the classic PeaZip context-menu icons. The publisher should confirm that these logo files may be redistributed. The eight user-supplied screenshots in `screenshots/` document the software and may depict third-party user interfaces or marks. They are not a transfer of those third-party rights.

## AI-assisted development

The project was developed with assistance from **ChatGPT by OpenAI, using GPT-6**. Assistance included implementation suggestions and iterations for the COM shell extension, MSIX packaging, Inno Setup installer, configuration interface, troubleshooting, and English technical documentation. The human project tester compiled and tested working builds on Windows 11, including a separate machine using PeaZip Portable. All code and generated documentation should remain subject to normal human review.

This disclosure credits the assistance received; **it does not mean that OpenAI is a project maintainer, copyright claimant, publisher, or endorser**.

## Other dependencies and distribution

- Windows Shell and MSIX APIs are Microsoft platform interfaces, not copied software covered by this MIT license.
- Inno Setup is an external compiler/tool with its own license; review its distribution and commercial-use requirements as appropriate.
- Private keys, PFX/P12 files and test signing credentials must never be committed. A **public** `.cer` may be released alongside a self-signed community installer after appropriate review and testing, but is not a publicly trusted signing identity. See [`SIGNING_AND_DISTRIBUTION.md`](SIGNING_AND_DISTRIBUTION.md).

**Independence notice:** Not affiliated with, sponsored by, or endorsed by Giorgio Tani, PeaZip, or OpenAI.


## Branding for v1.2.2

The three packaging PNG assets have been replaced by faithful resized copies of the PeaZip logo **supplied by the project contributor** (`StoreLogo.scale-100.png` and `StoreLogo.scale-400.png`). The PeaZip name and logo are associated with the upstream PeaZip project; inclusion in this unofficial community companion does **not** imply upstream endorsement or transfer of trademark rights. Confirm applicable logo redistribution permissions before public binary release. This project does not redistribute PeaZip's classic context-menu icon library.

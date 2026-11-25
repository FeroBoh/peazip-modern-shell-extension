"""Deterministic, source-only ZIP maker. Does not package MSIX/EXE/certificates."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = 'v1.2.3'
ALLOWED_ROOT_FILES = {
    '.gitignore', 'LICENSE', 'README.md', 'CHANGELOG.md',
    'CONTRIBUTING.md', 'SECURITY.md', 'INSTALL.md', 'BUILDING.md',
}
ALLOWED_DIRECTORIES = {
    '.github', 'src', 'packaging', 'installer', 'tools', 'tests', 'docs', 'screenshots'
}
EXCLUDED_PARTS = {'.git', '.vs', 'out', '__pycache__'}
BLOCKED_EXTENSIONS = {'.pfx', '.p12', '.key', '.cer', '.msix', '.msixbundle',
                      '.exe', '.dll', '.obj', '.pdb', '.lib', '.exp', '.log'}


def files_to_pack():
    for p in sorted(ROOT.rglob('*')):
        if not p.is_file():
            continue
        rel = p.relative_to(ROOT)
        if any(part in EXCLUDED_PARTS for part in rel.parts):
            continue
        if len(rel.parts) == 1:
            if rel.name not in ALLOWED_ROOT_FILES:
                continue
        elif rel.parts[0] not in ALLOWED_DIRECTORIES:
            continue
        if p.suffix.lower() in BLOCKED_EXTENSIONS:
            raise RuntimeError(f'Disallowed binary/key in expected source path: {rel}')
        yield p, rel


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path,
                        default=ROOT.parent / f'PeaZip-ModernMenu-{VERSION}-GitHub-Source.zip')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if output.is_relative_to(ROOT):
        parser.error('Output must be outside the source tree')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for p, rel in files_to_pack():
            info = zipfile.ZipInfo(f'PeaZip-ModernMenu-{VERSION}/{rel.as_posix()}',
                                   date_time=(2026, 11, 24, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            zf.writestr(info, p.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    sums = output.with_suffix(output.suffix + '.sha256')
    sums.write_text(f'{digest}  {output.name}\n', encoding='ascii')
    print(f'Wrote {output} ({output.stat().st_size} bytes)')
    print(f'SHA-256: {digest}')
    print(f'Checksum: {sums}')


if __name__ == '__main__':
    main()

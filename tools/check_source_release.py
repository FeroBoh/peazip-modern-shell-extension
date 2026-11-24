"""Read-only source-release hygiene check. No external Python dependencies."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
forbidden_suffixes = {'.pfx', '.p12', '.key', '.cer', '.msix', '.msixbundle', '.exe', '.dll', '.obj', '.pdb', '.lib', '.exp'}
ignored_development_dirs = {'out', '.git', '__pycache__', '.vs'}
problems = []
for p in root.rglob('*'):
    rel = p.relative_to(root)
    if any(part in ignored_development_dirs for part in rel.parts):
        continue  # normal git/dev files are never included by Make-Source-Release.py
    if p.is_file() and p.suffix.lower() in forbidden_suffixes:
        problems.append(f'binary or signing artifact included: {rel}')
    if p.is_file() and p.suffix.lower() in {'.ps1', '.cmd', '.iss', '.md', '.cpp', '.def', '.xml', '.yml', '.py'}:
        try:
            content = p.read_text(encoding='utf-8')
        except UnicodeError:
            problems.append(f'non-UTF8 text file: {rel}')
            continue
        if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', content):
            problems.append(f'embedded private key: {rel}')
        if re.search(r'C:\\Users\\Admin\\Desktop\\PeaZip-ModernShellExtension\d*\\', content, re.I):
            problems.append(f'tester-specific absolute source path: {rel}')

assert (root / 'LICENSE').is_file(), 'Missing LICENSE'
assert (root / 'docs' / 'RELEASE_CHECKLIST.md').is_file(), 'Missing release gate'
if problems:
    raise SystemExit('FAILED:\n' + '\n'.join(problems))
print('PASS: distributable sources have no compiled/credential artifacts or tester-specific source paths')

"""Prevent ISPP from parsing Pascal #13#10 as an unknown directive.

This is an offline syntactic regression check, not a substitute for ISCC.
"""
from pathlib import Path
import re

iss = (Path(__file__).resolve().parents[1] / "installer/PeaZip-ModernMenu.iss").read_text(encoding="utf-8")
for number, line in enumerate(iss.splitlines(), 1):
    if re.match(r"^\s*#", line):
        assert re.match(r"^\s*#(?:define|include|if|ifdef|ifndef|elif|else|endif|pragma|error|emit|expr|file|for|sub|endfor|endsub)\b", line), (number, line)
assert iss.count("#13#10") >= 6
assert "Result := 'MSIX installation or update failed" in iss
print("PASS: no Pascal character literals mistaken for top-level ISPP directives")

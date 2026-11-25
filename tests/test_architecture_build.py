"""Offline checks of the fail-fast x64 MSVC build fix."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ps1 = (root / "tools/Build-MSIX.ps1").read_text(encoding="utf-8")
cmd = (root / "tools/Build-x64.cmd").read_text(encoding="ascii")
assert "VSCMD_ARG_TGT_ARCH" in ps1
assert "Host(?:x64|x86)" in ps1
assert "Get-ChildItem -LiteralPath $obj -Force | Remove-Item" in ps1
assert ps1.index("$compiler -notmatch") < ps1.index("Get-ChildItem -LiteralPath $obj")
assert all(x in cmd for x in ["vswhere.exe", "VsDevCmd.bat", "-arch=x64", "-host_arch=x64", "Build-MSIX.ps1"])
assert "1.2.2.0" in ps1
print("PASS: x64 build wrapper, toolchain guard, stale-object cleanup and unchanged version")

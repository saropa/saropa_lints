import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scripts.modules._code_comment_metrics import (
    _dart_comment_lines,
    _iter_files,
    _physical_line_count,
    _python_comment_lines,
    _skip_dart_artifact,
    _ts_comment_lines,
)

text = Path(
    "plan/history/2026.04/2026.04.28/comment_coverage_wave1_batches_A-D.md",
).read_text(encoding="utf-8")
first100 = set(re.findall(r"`([^`]+)`", text))
first100 = {p for p in first100 if "/" in p and p.endswith((".dart", ".ts", ".py"))}
print("first100", len(first100))
next100 = [
    line.strip()
    for line in Path("agent_next100_paths.txt").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
toadd = [p for p in next100 if p not in first100]
print("to add (next100 minus first100)", len(toadd))
Path("agent_tofill_64.txt").write_text("\n".join(toadd) + "\n", encoding="utf-8")

root = Path(__file__).resolve().parent
rows: list[tuple[str, int, int, float]] = []

def one(path: Path, templates: bool, scan_py: bool) -> None:
    t = path.read_text(encoding="utf-8", errors="replace")
    phys = _physical_line_count(t)
    if phys < 15:
        return
    if scan_py:
        c = len(_python_comment_lines(t))
    elif templates:
        c = len(_ts_comment_lines(t))
    else:
        c = len(_dart_comment_lines(t))
    rel = path.relative_to(root).as_posix()
    ratio = c / phys if phys else 0.0
    rows.append((rel, phys, c, ratio))

for p in [p for p in _iter_files(root / "lib", ".dart") if not _skip_dart_artifact(p)]:
    one(p, False, False)
for p in _iter_files(root / "test", ".dart"):
    one(p, False, False)
for p in _iter_files(root / "bin", ".dart"):
    one(p, False, False)
if (root / "packages").is_dir():
    for pkg in sorted((root / "packages").iterdir()):
        if pkg.is_dir():
            for p in [p for p in _iter_files(pkg / "lib", ".dart") if not _skip_dart_artifact(p)]:
                one(p, False, False)
for p in _iter_files(root / "extension" / "src", ".ts"):
    one(p, True, False)
for p in _iter_files(root / "scripts", ".py"):
    one(p, False, True)
rows.sort(key=lambda x: (x[3], -x[1], x[0]))
used = set(first100) | set(toadd)
extra: list[str] = []
for rel, phys, c, ratio in rows[200:]:
    if rel in used:
        continue
    extra.append(rel)
    if len(extra) >= 36:
        break
print("extra36", len(extra))
Path("agent_tofill_extra36.txt").write_text("\n".join(extra) + "\n", encoding="utf-8")
all100 = toadd + extra
print("total new100", len(all100))
Path("agent_tofill_100.txt").write_text("\n".join(all100) + "\n", encoding="utf-8")

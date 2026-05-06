"""One-off repair: restore newlines after a buggy batch insert (joined without \\n).

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def _repair_dart_first_physical_line(line: str) -> str | None:
    core = line.rstrip("\r\n")
    has_sentinel = "comment-coverage: module overview (batch)" in core
    has_shebang_glue = "`plans/COMMENT_COVERAGE_PLAN.md`.#!/" in core and "\n#!/" not in core
    if not has_sentinel and not has_shebang_glue:
        return None
    if line.count("\n") > 1:
        return None
    if not has_shebang_glue and "import " not in line and "#!" not in line and "part of " not in line:
        return None
    s = core
    # Backtick-ended paths in doc text (e.g. `` `...md`.#!/ ``) must split before shebang/import.
    s = s.replace("`///", "`\n///")
    junctions = [
        ("CONTRIBUTING.md.", "import "),
        ("`plans/COMMENT_COVERAGE_PLAN.md`.", "#!/"),
        ("plans/COMMENT_COVERAGE_PLAN.md.", "#!/"),
        ("plans/COMMENT_COVERAGE_PLAN.md.", "import '"),
        ('plans/COMMENT_COVERAGE_PLAN.md.', 'import "'),
        ("plans/COMMENT_COVERAGE_PLAN.md.", "part of "),
    ]
    for prefix, start in junctions:
        key = prefix + start
        if key in s:
            s = s.replace(key, prefix + "\n" + start, 1)
            break
    s = s.replace(").///", ").\n///")
    s = s.replace(".///", ".\n///")
    while "//////" in s:
        s = s.replace("//////", "\n///\n///")
    if s == core:
        return None
    return s


def _repair_ts_first_physical_line(line: str) -> str | None:
    if "comment-coverage: module overview (batch)" not in line:
        return None
    if " */import " not in line and " */import*" not in line:
        # e.g. `*/import * as`
        if " */import" not in line:
            return None
    if line.count("\n") > 1:
        return None
    s = line.rstrip("\r\n")
    if " */import" not in s:
        return None
    s2 = s.replace(" */import", " */\nimport", 1)
    return s2 if s2 != s else None


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    proc = subprocess.run(
        ["git", "grep", "-l", "comment-coverage: module overview (batch)", "--", "*.dart", "*.ts"],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    paths = [root / p for p in proc.stdout.splitlines() if p.strip()]
    dart_fixed = 0
    ts_fixed = 0
    for path in paths:
        if "apply_comment_coverage" in str(path) or "repair_comment_batch" in str(path):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines(keepends=True)
        if not lines:
            continue
        changed = False
        if path.suffix == ".dart":
            for i, line in enumerate(lines):
                if line.count("\n") > 1:
                    continue
                new_line = _repair_dart_first_physical_line(line)
                if new_line is None:
                    continue
                nl = "\r\n" if line.endswith("\r\n") else "\n"
                lines[i] = new_line + nl
                changed = True
            if changed:
                path.write_text("".join(lines), encoding="utf-8", newline="")
                dart_fixed += 1
        elif path.suffix == ".ts":
            first = lines[0]
            new_first = _repair_ts_first_physical_line(first)
            if new_first is not None:
                nl = "\r\n" if first.endswith("\r\n") else "\n"
                lines[0] = new_first.rstrip("\r\n") + nl
                path.write_text("".join(lines), encoding="utf-8", newline="")
                ts_fixed += 1
    print(f"Repaired Dart files: {dart_fixed}, TypeScript files: {ts_fixed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

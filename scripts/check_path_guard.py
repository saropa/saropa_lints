#!/usr/bin/env python3
"""Fail if CLI/bin Dart files use File()/Directory() with interpolation but lack path_guard.

Scans ``lib/src/cli/`` and ``bin/`` for Dart files that construct ``File()`` or
``Directory()`` with string interpolation (``$``) or concatenation (``+``) in
the argument — the pattern that ``avoid_path_traversal`` flags — and verifies
the file imports ``path_guard.dart`` or calls ``sanitizePath``.

Run from repository root::

    python scripts/check_path_guard.py

Exit codes:
    0 - every file with interpolated paths imports path_guard or sanitizes
    1 - one or more files are missing the guard
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Directories where user-supplied paths reach File()/Directory().
_SCAN_DIRS = ["lib/src/cli", "bin"]

# Matches File()/Directory() whose argument uses interpolation ($) or
# concatenation (+).  The \s* spans newlines so multi-line constructors
# like `File(\n  '$root/...',\n)` are caught.
_FILE_DIR_INTERP = re.compile(
    r"\b(?:File|Directory)\(\s*'[^']*\$"
    r"|"
    r'\b(?:File|Directory)\(\s*"[^"]*\$'
    r"|"
    r"\b(?:File|Directory)\([^)]*\+",
    re.DOTALL,
)

# Import or direct usage that proves the file is guarded.
_GUARD_PRESENT = re.compile(
    r"import\s+'[^']*path_guard\.dart'"
    r"|"
    r"\bsanitizePath\b"
)

# Files whose File()/Directory() interpolation is verified safe (no user input).
# Each entry needs a one-line reason.
_ALLOWLIST: dict[str, str] = {
    "bin/scan.dart": "dateFolder is a timestamp prefix, not user input",
}


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    failures: list[str] = []

    for scan_dir in _SCAN_DIRS:
        target = repo / scan_dir
        if not target.is_dir():
            continue
        for dart_file in sorted(target.rglob("*.dart")):
            # Skip generated and part files — they inherit their parent's imports.
            if dart_file.name.endswith(".g.dart"):
                continue

            content = dart_file.read_text(encoding="utf-8", errors="replace")

            # Does this file construct File/Directory with interpolation?
            if not _FILE_DIR_INTERP.search(content):
                continue

            # Is path_guard imported or sanitizePath called?
            if _GUARD_PRESENT.search(content):
                continue

            rel = dart_file.relative_to(repo)
            rel_posix = str(rel).replace("\\", "/")

            # Skip verified-safe files (no user input reaches the path).
            if rel_posix in _ALLOWLIST:
                continue
            failures.append(rel_posix)

    if not failures:
        print("path_guard check: all interpolated File()/Directory() sites are guarded.")
        return 0

    print("path_guard check FAILED — these files use File()/Directory() with")
    print("interpolation but do not import path_guard.dart or call sanitizePath():")
    print()
    for f in failures:
        print(f"  {f}")
    print()
    print("Fix: import 'package:saropa_lints/src/cli/path_guard.dart' and call")
    print("sanitizePath() on the user-supplied path before constructing File/Directory.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

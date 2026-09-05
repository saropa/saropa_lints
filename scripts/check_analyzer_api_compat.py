#!/usr/bin/env python3
"""Fail if rule files use removed or renamed analyzer package APIs.

The ``analyzer`` package periodically removes deprecated getters and renames
AST node accessors between major versions.  These breakages compile fine
under ``dart analyze`` (the rule files are loaded at runtime via the plugin
system, not statically imported by the main package) but crash the LSP
server and scan CLI at startup with exit 255.

This script greps ``lib/src/rules/`` for known-removed patterns so CI
catches them before a user ever sees a crash.

Run from repository root::

    python scripts/check_analyzer_api_compat.py

Exit codes:
    0 - no removed API usage found
    1 - one or more violations detected
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Each entry: (compiled regex, human-readable description, fix suggestion).
# Patterns match on a single line of Dart source.  Keep them narrow enough
# to avoid false positives on comments and strings — a few escapes are
# worth it to avoid flagging `// ClassDeclaration.name was removed`.
_REMOVED_APIS: list[tuple[re.Pattern[str], str, str]] = [
    # analyzer 12.x: ClassDeclaration.name (SimpleIdentifier) removed;
    # replaced by nameToken (Token).  The `.name.lexeme` chain is the
    # telltale — `.nameToken.lexeme` is the replacement.
    (
        re.compile(
            r"(?<!\w)"                  # not preceded by a word char
            r"(?:ClassDeclaration"      # type-qualified access
            r"|enclosingClass"          # common variable name
            r")"
            r"\s*[.?]\s*\bname\b"       # .name or ?.name
            r"\s*\.\s*lexeme"           # .lexeme — the dead giveaway
        ),
        "ClassDeclaration.name.lexeme (removed in analyzer 12.x)",
        "Use .nameToken.lexeme instead",
    ),
    # analyzer 12.x: ClassDeclaration.members removed; replaced by
    # bodyMembers (see lib/src/analyzer_compat.dart).
    (
        re.compile(
            r"(?<!\w)"
            r"(?:ClassDeclaration"
            r"|enclosingClass"
            r")"
            r"\s*[.?]\s*\bmembers\b"
            r"(?!\s*[=])"               # not an assignment (local var)
        ),
        "ClassDeclaration.members (removed in analyzer 12.x)",
        "Use .bodyMembers instead (see lib/src/analyzer_compat.dart)",
    ),
]

# Files with verified-safe matches (the pattern appears in a comment, not
# code).  Each entry needs a one-line reason.
_ALLOWLIST: dict[str, str] = {
    # Comment explaining the migration — not actual usage.
    "lib/src/rules/packages/awesome_notifications_rules.dart":
        "comment documenting the migration, not actual .name usage",
}


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    rules_dir = repo / "lib" / "src" / "rules"

    if not rules_dir.is_dir():
        print(f"check_analyzer_api_compat: {rules_dir} not found, skipping.")
        return 0

    failures: list[str] = []

    for dart_file in sorted(rules_dir.rglob("*.dart")):
        # Skip generated files.
        if dart_file.name.endswith(".g.dart"):
            continue

        rel = dart_file.relative_to(repo)
        rel_posix = str(rel).replace("\\", "/")

        # Skip allowlisted files.
        if rel_posix in _ALLOWLIST:
            continue

        content = dart_file.read_text(encoding="utf-8", errors="replace")

        for line_no, line in enumerate(content.splitlines(), start=1):
            # Skip comment-only lines — the pattern may appear in a
            # migration note explaining what was removed.
            stripped = line.lstrip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue

            for pattern, description, fix in _REMOVED_APIS:
                if pattern.search(line):
                    failures.append(
                        f"  {rel_posix}:{line_no}: {description}\n"
                        f"    Fix: {fix}\n"
                        f"    Line: {stripped.strip()}"
                    )

    if not failures:
        print(
            "check_analyzer_api_compat: no removed analyzer API usage found "
            f"({rules_dir.relative_to(repo)})."
        )
        return 0

    print("check_analyzer_api_compat FAILED — these files use removed or")
    print("renamed analyzer package APIs that will crash at runtime:")
    print()
    for f in failures:
        print(f)
    print()
    print("These APIs compile under `dart analyze` because rule files are")
    print("loaded at runtime, but crash the LSP server and scan CLI at")
    print("startup (exit 255).  See scripts/check_analyzer_api_compat.py")
    print("to add new patterns when the analyzer package removes more APIs.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

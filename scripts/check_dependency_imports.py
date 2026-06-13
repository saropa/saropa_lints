#!/usr/bin/env python3
"""Fail if shipped code imports a package not declared in pubspec dependencies.

Standalone, deterministic guard for the defect that sank v13.12.6 and v13.12.7
(2026-06-12): both imported ``package:meta/meta.dart`` from lib/ with no
``meta`` entry under pubspec ``dependencies``. ``dart pub publish`` rejects
that, but only on the tag-triggered CI job — after the version tag is already
pushed. No earlier gate caught it: lib/** is in ``analyzer.exclude`` (plugin
dogfooding), so no ``dart analyze`` run inspects lib/ imports, and the exit
code of ``dart pub publish --dry-run`` for this case differs by Dart version
(warning on 3.10.x/3.12.1, hard rejection on the publish job's stable SDK), so
the existing dry-run step lets it through as a non-fatal warning.

This check is version-independent: it parses pubspec and the Dart directive
headers directly. Shares the single source of truth with the release audit
(``get_dependency_import_status`` in ``scripts/modules/_audit_checks.py``).

Run from repository root::

    python scripts/check_dependency_imports.py

Exit codes:
    0 - every shipped import is a declared dependency
    1 - one or more imported packages are missing from dependencies
"""

from __future__ import annotations

import sys
from pathlib import Path

# Allow running as `python scripts/check_dependency_imports.py` from the
# project root: add the repo root so `scripts.modules.*` imports resolve (same
# bootstrap as publish.py).
_repo_root = str(Path(__file__).resolve().parent.parent)
if _repo_root not in sys.path:
    sys.path.insert(0, _repo_root)

from scripts.modules._audit_checks import get_dependency_import_status


def main() -> int:
    project_dir = Path(__file__).resolve().parent.parent
    status = get_dependency_import_status(project_dir)
    missing = status.get("missing", {})
    if not missing:
        print("OK: every package imported by lib/ and bin/ is a declared dependency.")
        return 0

    print(
        "ERROR: shipped code imports package(s) not declared in pubspec "
        "`dependencies` (dart pub publish would reject this):",
        file=sys.stderr,
    )
    for pkg in sorted(missing):
        files = missing[pkg]
        shown = ", ".join(files[:5]) + (
            f" (+{len(files) - 5} more)" if len(files) > 5 else ""
        )
        print(f"  - {pkg}: add `{pkg}:` to dependencies (imported by {shown})", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

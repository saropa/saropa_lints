#!/usr/bin/env python3
"""Fail if a shipped doc links to a path .pubignore excludes from the package.

Standalone, deterministic guard for the defect that misplaced
``PACKAGE_VIBRANCY.md`` under ``plans/guides/`` (2026-09-02): the file itself
shipped fine, but ``.pubignore`` now excludes the whole ``plans/`` directory
from the pub.dev tarball, so any doc under ``doc/`` (which IS shipped) that
links into ``plans/`` would produce a dead relative link for anyone reading
the published package on pub.dev.

This check only looks at *shipped* docs (``doc/**``, ``README.md``,
top-level ``*.md`` not covered by a ``.pubignore`` rule) and flags relative
markdown links (``[text](path)``) whose target falls under an excluded
directory prefix from ``.pubignore``. It does not resolve every gitignore
glob feature — directory-prefix excludes (``plans/``, ``bugs/``, ``scripts/``)
are the only pattern shape this repo's ``.pubignore`` currently uses for
doc-adjacent paths, and that is the failure mode this guard targets.

Run from repository root::

    python scripts/check_doc_links_excluded_paths.py

Exit codes:
    0 - no shipped doc links into an excluded path
    1 - one or more shipped docs link into a path .pubignore excludes
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Directory-prefix .pubignore rules relevant to doc cross-links. Kept as a
# short explicit list rather than a full gitignore parser: the repo's
# .pubignore only uses directory-prefix excludes for doc-adjacent paths, and
# a full parser would be undertested machinery for a narrow guard.
_EXCLUDED_PREFIXES = ("plans/", "bugs/", "scripts/")

_MD_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def _shipped_doc_files(repo_root: Path) -> list[Path]:
    candidates = list((repo_root / "doc").rglob("*.md"))
    readme = repo_root / "README.md"
    if readme.exists():
        candidates.append(readme)
    return candidates


def _violations(doc_path: Path, repo_root: Path) -> list[str]:
    text = doc_path.read_text(encoding="utf-8")
    found = []
    for match in _MD_LINK.finditer(text):
        target = match.group(1).split("#", 1)[0].strip()
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        # Normalize a repo-root-relative link the same way a reader on
        # GitHub or pub.dev would resolve it.
        normalized = target.lstrip("/")
        if any(normalized.startswith(prefix) for prefix in _EXCLUDED_PREFIXES):
            rel = doc_path.relative_to(repo_root)
            found.append(f"{rel}: links to '{target}', excluded by .pubignore")
    return found


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    violations: list[str] = []
    for doc_path in _shipped_doc_files(repo_root):
        violations.extend(_violations(doc_path, repo_root))

    if not violations:
        print("OK: no shipped doc links into a .pubignore-excluded path.")
        return 0

    print(
        "ERROR: shipped doc(s) link to path(s) excluded from the pub.dev "
        "package by .pubignore (dead link for anyone reading the published "
        "package):",
        file=sys.stderr,
    )
    for v in violations:
        print(f"  - {v}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

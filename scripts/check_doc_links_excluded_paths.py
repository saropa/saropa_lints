#!/usr/bin/env python3
"""Fail if a shipped doc has a broken relative link, or links into a path
.pubignore excludes from the package.

Standalone, deterministic guard for two related defects found in the same
audit (2026-09-02):

1. ``PACKAGE_VIBRANCY.md`` was misplaced under ``plans/guides/``, and
   ``.pubignore`` excludes the whole ``plans/`` directory from the pub.dev
   tarball — so any doc under ``doc/`` (which IS shipped) that links into
   ``plans/`` produces a dead relative link for anyone reading the published
   package on pub.dev.
2. ``README.md`` separately had two dead relative links: one to a file that
   no longer exists at all, one into an excluded path. Both classes are
   worth catching with the same file-walking pass, so this check does both:
   flag any relative link whose target does not exist on disk, and
   separately flag any relative link (existing or not) whose target falls
   under an excluded directory prefix.

Link targets are resolved relative to the linking file's own directory
(standard Markdown/GitHub semantics), not the repo root — a link in
``doc/guides/foo.md`` to ``../../plans/x.md`` is followed from
``doc/guides/``, not from the repo root.

This does not resolve every gitignore glob feature — directory-prefix
excludes (``plans/``, ``bugs/``, ``scripts/``) are the only pattern shape
this repo's ``.pubignore`` currently uses for doc-adjacent paths, and that
is the failure mode this guard targets.

Run from repository root::

    python scripts/check_doc_links_excluded_paths.py

Exit codes:
    0 - no shipped doc has a broken link or a link into an excluded path
    1 - one or more violations found
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


def _resolve_target(doc_path: Path, target: str, repo_root: Path) -> Path:
    # A leading "/" is repo-root-anchored (GitHub renders it that way);
    # anything else resolves relative to the linking file's own directory.
    if target.startswith("/"):
        return (repo_root / target.lstrip("/")).resolve()
    return (doc_path.parent / target).resolve()


def _violations(doc_path: Path, repo_root: Path) -> list[str]:
    text = doc_path.read_text(encoding="utf-8")
    rel_doc = doc_path.relative_to(repo_root)
    found = []
    for match in _MD_LINK.finditer(text):
        target = match.group(1).split("#", 1)[0].strip()
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue

        resolved = _resolve_target(doc_path, target, repo_root)
        try:
            resolved_rel = resolved.relative_to(repo_root).as_posix()
        except ValueError:
            # Link escapes the repo entirely; not this check's concern.
            continue

        if any(resolved_rel.startswith(prefix) for prefix in _EXCLUDED_PREFIXES):
            found.append(
                f"{rel_doc}: links to '{target}', excluded from the pub.dev "
                "package by .pubignore"
            )
        elif not resolved.exists():
            found.append(f"{rel_doc}: links to '{target}', which does not exist")

    return found


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    violations: list[str] = []
    for doc_path in _shipped_doc_files(repo_root):
        violations.extend(_violations(doc_path, repo_root))

    if not violations:
        print("OK: no shipped doc has a broken link or a link into an excluded path.")
        return 0

    print(
        "ERROR: shipped doc(s) have broken relative link(s) or link(s) into "
        "a path excluded from the pub.dev package:",
        file=sys.stderr,
    )
    for v in violations:
        print(f"  - {v}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

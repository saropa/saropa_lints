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
   under a directory ``.pubignore`` excludes.

Link targets are resolved relative to the linking file's own directory
(standard Markdown/GitHub semantics), not the repo root — a link in
``doc/guides/foo.md`` to ``../../plans/x.md`` is followed from
``doc/guides/``, not from the repo root.

Both inline links (``[text](path)``) and reference-style links
(``[text][ref]`` with a ``[ref]: path`` definition elsewhere in the file)
are checked.

Excluded directory prefixes are read directly from ``.pubignore`` (any
non-comment line ending in ``/``) rather than hardcoded, so a new exclusion
added there is picked up automatically. This does not implement full
gitignore glob semantics (no wildcards, no negation) — directory-prefix
excludes are the only pattern shape this repo's ``.pubignore`` uses, and
that is the failure mode this guard targets.

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

_INLINE_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
_REF_LINK_USE = re.compile(r"\[[^\]]*\]\[([^\]]+)\]")
_REF_LINK_DEF = re.compile(r"^\s*\[([^\]]+)\]:\s*(\S+)", re.MULTILINE)


def _excluded_prefixes(repo_root: Path) -> tuple[str, ...]:
    pubignore = repo_root / ".pubignore"
    prefixes = []
    for line in pubignore.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.endswith("/"):
            prefixes.append(stripped.lstrip("/"))
    return tuple(prefixes)


def _shipped_doc_files(repo_root: Path) -> list[Path]:
    candidates = list((repo_root / "doc").rglob("*.md"))
    readme = repo_root / "README.md"
    if readme.exists():
        candidates.append(readme)
    return candidates


def _resolve_target(doc_path: Path, target: str, repo_root: Path) -> Path:
    # Normalize accidental Windows-style separators before resolving.
    target = target.replace("\\", "/")
    # A leading "/" is repo-root-anchored (GitHub renders it that way);
    # anything else resolves relative to the linking file's own directory.
    if target.startswith("/"):
        return (repo_root / target.lstrip("/")).resolve()
    return (doc_path.parent / target).resolve()


def _link_targets(text: str) -> list[str]:
    targets = [m.group(1) for m in _INLINE_LINK.finditer(text)]
    ref_defs = dict(_REF_LINK_DEF.findall(text))
    for ref in _REF_LINK_USE.finditer(text):
        target = ref_defs.get(ref.group(1))
        if target:
            targets.append(target)
    return targets


def _violations(doc_path: Path, repo_root: Path, excluded_prefixes: tuple[str, ...]) -> list[str]:
    text = doc_path.read_text(encoding="utf-8")
    rel_doc = doc_path.relative_to(repo_root)
    found = []
    for raw_target in _link_targets(text):
        # Strip a trailing anchor or query string; neither affects which
        # file on disk the link points to.
        target = raw_target.split("#", 1)[0].split("?", 1)[0].strip()
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue

        resolved = _resolve_target(doc_path, target, repo_root)
        try:
            resolved_rel = resolved.relative_to(repo_root).as_posix()
        except ValueError:
            # Link escapes the repo entirely; not this check's concern.
            continue

        if any(resolved_rel.startswith(prefix) for prefix in excluded_prefixes):
            found.append(
                f"{rel_doc}: links to '{raw_target}', excluded from the pub.dev "
                "package by .pubignore"
            )
        elif not resolved.exists():
            found.append(f"{rel_doc}: links to '{raw_target}', which does not exist")

    return found


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    excluded_prefixes = _excluded_prefixes(repo_root)
    violations: list[str] = []
    for doc_path in _shipped_doc_files(repo_root):
        violations.extend(_violations(doc_path, repo_root, excluded_prefixes))

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

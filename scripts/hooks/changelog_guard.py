"""Changelog version-drift guard for git pre-commit and Claude hooks.

Prevents the two most common version-drift mistakes:
  1. Multiple unreleased sections in CHANGELOG.md (automated sessions
     creating new sections instead of appending to the existing one).
  2. Version numbers in pubspec.yaml or extension/package.json that
     don't match the last published git tag (premature version bumps).

Two invocation modes, one script:
  * **git pre-commit** passes staged file paths as command-line arguments.
  * **Claude PostToolUse** passes a JSON payload on stdin; the edited file
    is read from ``tool_input.file_path``.

Exit codes: 0 = clean, 2 = version-drift found.

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

# Repo root is two levels up: scripts/hooks/changelog_guard.py.
_REPO_ROOT = Path(__file__).resolve().parents[2]

# Matches " - Unreleased" or " — Unreleased" (em-dash) with typo tolerance.
_UNRELEASED_SUFFIX_PAT = r"\s*(?:-|—)\s*unreleas\w*"


def _paths_from_stdin() -> list[str]:
    """Pull the edited file path from a Claude Code PostToolUse payload."""
    if sys.stdin.isatty():
        return []
    data = sys.stdin.read()
    if not data.strip():
        return []
    try:
        payload = json.loads(data)
    except json.JSONDecodeError:
        return []
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path")
    return [file_path] if file_path else []


def _touches_versioned_file(paths: list[str]) -> bool:
    """Whether any path is CHANGELOG.md, pubspec.yaml, or package.json."""
    watched = {"changelog.md", "pubspec.yaml", "package.json"}
    for p in paths:
        if Path(p).name.lower() in watched:
            return True
    return False


def _count_unreleased_sections(changelog: Path) -> int:
    """Count unreleased sections (both ## [Unreleased] and ## [X.Y.Z] — Unreleased)."""
    if not changelog.is_file():
        return 0
    content = changelog.read_text(encoding="utf-8")
    # Pure [Unreleased] headings at line start
    pure = len(re.findall(r"^## \[Unreleased\]", content, re.MULTILINE))
    # Versioned headings with an unreleased suffix at line start
    suffixed = len(re.findall(
        rf"^## \[[^\]]+\]{_UNRELEASED_SUFFIX_PAT}",
        content,
        re.MULTILINE | re.IGNORECASE,
    ))
    return pure + suffixed


def _version_sort_key(version: str) -> tuple:
    """Sort key where prerelease < stable of the same base
    (16.0.0-beta.1 < 16.0.0-beta.2 < 16.0.0), matching
    scripts/modules/_version_changelog.parse_version."""
    match = re.match(r"^(\d+\.\d+\.\d+)(?:-(.+))?$", version)
    if not match:
        return (0, 0, 0, 0, "")
    base = tuple(int(x) for x in match.group(1).split("."))
    pre = match.group(2)
    return (*base, 1, "") if pre is None else (*base, 0, pre)


def _get_last_published_tag() -> str | None:
    """Return the latest vX.Y.Z(-prerelease) tag, or None if no tags exist.

    Must accept prerelease tags — a stable-only regex misses the true
    last-published version during a beta cycle (e.g. v16.0.0-beta.1) and
    falls back to an older stable tag instead, which turns a one-step
    forward bump into what looks like a many-version rollback.
    """
    try:
        result = subprocess.run(
            ["git", "tag", "--sort=-v:refname"],
            capture_output=True, text=True, cwd=_REPO_ROOT,
        )
        if result.returncode != 0:
            return None
        candidates = [
            line.strip() for line in result.stdout.strip().splitlines()
            if re.match(r"^v\d+\.\d+\.\d+(-[\w.]+)?$", line.strip())
        ]
        if not candidates:
            return None
        return max(candidates, key=lambda t: _version_sort_key(t.lstrip("v")))
    except FileNotFoundError:
        pass
    return None


def _read_pubspec_version() -> str | None:
    """Extract version from pubspec.yaml."""
    pubspec = _REPO_ROOT / "pubspec.yaml"
    if not pubspec.is_file():
        return None
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^version:\s*(.+)$", line)
        if m:
            return m.group(1).strip()
    return None


def _read_package_json_version() -> str | None:
    """Extract version from extension/package.json."""
    pkg = _REPO_ROOT / "extension" / "package.json"
    if not pkg.is_file():
        return None
    try:
        data = json.loads(pkg.read_text(encoding="utf-8"))
        return data.get("version")
    except (json.JSONDecodeError, OSError):
        return None


def main() -> int:
    """Run all changelog/version guards; exit 2 on any failure."""
    paths = list(sys.argv[1:]) or _paths_from_stdin()

    # Only run when a versioned file is being touched
    if not _touches_versioned_file(paths):
        return 0

    errors: list[str] = []

    # Guard 1: multiple unreleased sections
    changelog = _REPO_ROOT / "CHANGELOG.md"
    count = _count_unreleased_sections(changelog)
    if count > 1:
        errors.append(
            f"CHANGELOG.md has {count} unreleased sections — "
            f"merge them into one before committing."
        )

    # Guard 2: version drift from last published tag
    last_tag = _get_last_published_tag()
    if last_tag:
        # Strip leading 'v' from tag
        tag_version = last_tag.lstrip("v")

        pubspec_ver = _read_pubspec_version()
        if pubspec_ver and pubspec_ver != tag_version:
            errors.append(
                f"pubspec.yaml version ({pubspec_ver}) does not match "
                f"last published tag ({last_tag}). The publish script "
                f"handles version bumps — reset to {tag_version}."
            )

        pkg_ver = _read_package_json_version()
        if pkg_ver and pkg_ver != tag_version:
            errors.append(
                f"extension/package.json version ({pkg_ver}) does not "
                f"match last published tag ({last_tag}). The publish "
                f"script handles version bumps — reset to {tag_version}."
            )

    if not errors:
        return 0

    sys.stderr.write(
        "Changelog/version guard failed:\n"
        + "\n".join(f"  - {e}" for e in errors)
        + "\n\nSee CHANGELOG.md maintenance notes for the Unreleased "
        "convention.\n"
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

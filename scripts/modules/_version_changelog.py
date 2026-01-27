"""
Version and changelog utilities.

Reads version/name from pubspec.yaml, validates and displays
changelog entries for the publish workflow.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
    print_warning,
)


def get_version_from_pubspec(pubspec_path: Path) -> str:
    """Read version string from pubspec.yaml."""
    content = pubspec_path.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)", content, re.MULTILINE)
    if not match:
        raise ValueError("Could not find version in pubspec.yaml")
    return match.group(1)


def get_package_name(pubspec_path: Path) -> str:
    """Read package name from pubspec.yaml."""
    content = pubspec_path.read_text(encoding="utf-8")
    match = re.search(r"^name:\s*(.+)$", content, re.MULTILINE)
    if not match:
        raise ValueError("Could not find name in pubspec.yaml")
    return match.group(1).strip()


def get_latest_changelog_version(changelog_path: Path) -> str | None:
    """Extract the latest version from CHANGELOG.md."""
    if not changelog_path.exists():
        return None
    content = changelog_path.read_text(encoding="utf-8")
    match = re.search(r"##\s*\[?(\d+\.\d+\.\d+)\]?", content)
    return match.group(1) if match else None


def validate_changelog_version(
    project_dir: Path, version: str
) -> str | None:
    """Validate version exists in CHANGELOG and extract release notes.

    Returns:
        Release notes text, empty string if section has no content,
        or None if the version heading is not found.
    """
    changelog_path = project_dir / "CHANGELOG.md"
    if not changelog_path.exists():
        return None

    content = changelog_path.read_text(encoding="utf-8")
    version_pattern = rf"##\s*\[?{re.escape(version)}\]?"
    if not re.search(version_pattern, content):
        return None

    pattern = (
        rf"(?s)##\s*\[?{re.escape(version)}\]?[^\n]*\n"
        rf"(.*?)(?=##\s*\[?\d+\.\d+\.\d+|$)"
    )
    match = re.search(pattern, content)
    return match.group(1).strip() if match else ""


def display_changelog(project_dir: Path) -> str | None:
    """Display the latest changelog entry.

    Returns:
        The latest changelog entry text, or None if not found.
    """
    changelog_path = project_dir / "CHANGELOG.md"
    if not changelog_path.exists():
        print_warning("CHANGELOG.md not found")
        return None

    content = changelog_path.read_text(encoding="utf-8")
    match = re.search(
        r"^(## \[?\d+\.\d+\.\d+\]?.*?)(?=^## |\Z)",
        content,
        re.MULTILINE | re.DOTALL,
    )

    if match:
        latest_entry = match.group(1).strip()
        print()
        print_colored("  CHANGELOG (latest entry):", Color.WHITE)
        print_colored("  " + "-" * 50, Color.CYAN)
        for line in latest_entry.split("\n"):
            print_colored(f"  {line}", Color.CYAN)
        print_colored("  " + "-" * 50, Color.CYAN)
        print()
        return latest_entry

    print_warning("Could not parse CHANGELOG.md")
    return None

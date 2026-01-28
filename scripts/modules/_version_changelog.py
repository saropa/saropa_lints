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
    """Display a summary of the latest changelog entry.

    Shows counts by section type (Added, Changed, Fixed, etc.)
    and warns if no items are found.

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

    if not match:
        print_warning("Could not parse CHANGELOG.md")
        return None

    latest_entry = match.group(1).strip()

    # Count items by section type
    section_counts: dict[str, int] = {}
    current_section = None
    for line in latest_entry.split("\n"):
        # Detect section headers like "### Added", "### Changed"
        section_match = re.match(r"^###\s+(\w+)", line)
        if section_match:
            current_section = section_match.group(1)
            section_counts.setdefault(current_section, 0)
        # Count bullet points
        elif current_section and re.match(r"^\s*-\s+", line):
            section_counts[current_section] += 1

    total_items = sum(section_counts.values())

    print()
    print_colored("  CHANGELOG:", Color.WHITE)

    if total_items == 0:
        print_warning("No items in latest changelog entry!")
    else:
        # Display summary by type
        summary_parts = []
        for section, count in section_counts.items():
            summary_parts.append(f"{count} {section}")
        print_colored(f"      {', '.join(summary_parts)}", Color.CYAN)

    print_colored(
        f"      See: CHANGELOG.md",
        Color.DIM,
    )
    print()
    return latest_entry

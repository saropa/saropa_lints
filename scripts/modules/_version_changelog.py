"""
Version and changelog utilities.

Reads version/name from pubspec.yaml, validates and displays
changelog entries for the publish workflow.

Version:   1.1
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

# Semantic version with optional pre-release suffix.
# Matches: 5.0.0, 5.0.0-beta.1, 5.0.0-rc.2, etc.
_VERSION_RE = r"\d+\.\d+\.\d+(?:-[\w]+(?:\.[\w]+)*)?"


def get_version_from_pubspec(pubspec_path: Path) -> str:
    """Read version string from pubspec.yaml."""
    content = pubspec_path.read_text(encoding="utf-8")
    match = re.search(
        rf"^version:\s*({_VERSION_RE})",
        content,
        re.MULTILINE,
    )
    if not match:
        raise ValueError("Could not find version in pubspec.yaml")
    return match.group(1)


def parse_version(version: str) -> tuple:
    """Parse a version string into a comparable sort key.

    Pre-release versions sort before stable for the same base:
        5.0.0-beta.1 < 5.0.0-beta.2 < 5.0.0

    Returns:
        Tuple suitable for comparison with < and >.
    """
    match = re.match(r"^(\d+\.\d+\.\d+)(?:-(.+))?$", version)
    if not match:
        raise ValueError(f"Invalid version: {version}")
    base = tuple(int(x) for x in match.group(1).split("."))
    pre = match.group(2)
    # No pre-release = stable = sorts after any pre-release of same base.
    # (0, suffix) for pre-release, (1,) for stable.
    if pre is None:
        return (*base, 1, "")
    return (*base, 0, pre)


def set_version_in_pubspec(pubspec_path: Path, new_version: str) -> None:
    """Write a new version string into pubspec.yaml."""
    content = pubspec_path.read_text(encoding="utf-8")
    updated = re.sub(
        rf"^(version:\s*){_VERSION_RE}",
        rf"\g<1>{new_version}",
        content,
        count=1,
        flags=re.MULTILINE,
    )
    if content == updated:
        raise ValueError(
            f"Failed to update version in {pubspec_path} - "
            "version pattern not found"
        )
    pubspec_path.write_text(updated, encoding="utf-8")


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
    match = re.search(rf"##\s*\[?({_VERSION_RE})\]?", content)
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
        rf"(.*?)(?=##\s*\[?{_VERSION_RE}|$)"
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
        rf"^(## \[?{_VERSION_RE}\]?.*?)(?=^## |\Z)",
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


def increment_version(version: str) -> str:
    """Increment version: 5.0.0 -> 5.0.1, 5.0.0-beta.1 -> 5.0.0-beta.2."""
    # Pre-release: increment the trailing number after the last dot
    pre_match = re.match(r"^(\d+\.\d+\.\d+-\w+\.)(\d+)$", version)
    if pre_match:
        prefix, num = pre_match.group(1), int(pre_match.group(2))
        return f"{prefix}{num + 1}"
    # Stable: increment patch
    parts = version.split(".")
    parts[-1] = str(int(parts[-1]) + 1)
    return ".".join(parts)


def rename_unreleased_to_version(
    changelog_path: Path, version: str
) -> bool:
    """Rename [Unreleased] heading to [version] before publishing.

    Returns:
        True if renamed, False if no [Unreleased] section found.

    Raises:
        ValueError: If both [Unreleased] and [version] sections exist.
    """
    content = changelog_path.read_text(encoding="utf-8")

    if not re.search(r"## \[Unreleased\]", content):
        return False

    version_pattern = rf"## \[{re.escape(version)}\]"
    if re.search(version_pattern, content):
        raise ValueError(
            f"CHANGELOG has both [Unreleased] and [{version}]. "
            f"Remove one before publishing."
        )

    content = re.sub(
        r"## \[Unreleased\]",
        f"## [{version}]",
        content,
        count=1,
    )
    changelog_path.write_text(content, encoding="utf-8")
    return True


def add_unreleased_section(changelog_path: Path) -> bool:
    """Add empty [Unreleased] section above the first versioned section.

    Returns:
        True if section was added, False if it already existed.
    """
    content = changelog_path.read_text(encoding="utf-8")

    if re.search(r"## \[Unreleased\]", content):
        return False

    # Insert before the first ---\n## [version] block
    content = re.sub(
        rf"(---\n)(## \[?{_VERSION_RE})",
        r"\1## [Unreleased]\n\n---\n\2",
        content,
        count=1,
    )

    changelog_path.write_text(content, encoding="utf-8")
    return True

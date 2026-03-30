"""
Version, changelog, and version-prompt utilities.

Reads version/name from pubspec.yaml, validates and displays
changelog entries, provides cross-platform version prompting,
and synchronizes version across pubspec and CHANGELOG for the
publish workflow.

Version:   2.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
import sys
import time
from pathlib import Path

from scripts.modules._utils import (
    Color,
    ExitCode,
    exit_with_error,
    print_colored,
    print_info,
    print_success,
    print_warning,
)
from scripts.modules._git_ops import tag_exists_on_remote

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

    # Already at the target version — nothing to do
    current = get_version_from_pubspec(pubspec_path)
    if current == new_version:
        return

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


def add_version_section(
    changelog_path: Path, version: str, message: str = "Version bump",
) -> bool:
    """Insert a new version section above the first existing version.

    Creates a ``## [version]`` heading with a single changelog entry,
    matching the project's ``---``-separated section format.

    Returns:
        True if the section was added, False if it already exists.
    """
    content = changelog_path.read_text(encoding="utf-8")

    # Don't duplicate an existing section
    if re.search(rf"## \[{re.escape(version)}\]", content):
        return False

    new_section = (
        f"---\n\n## [{version}]\n\n### Changed\n\n- {message}\n\n"
    )

    # Insert before the first ---\n[optional blank]\n## [version] block
    match = re.search(
        rf"---\n\n?## \[?{_VERSION_RE}", content,
    )
    if match:
        pos = match.start()
        content = content[:pos] + new_section + content[pos:]
    else:
        content = content.rstrip() + "\n\n" + new_section

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

    # Insert before the first ---\n[optional blank]\n## [version] block
    content = re.sub(
        rf"(---)\n\n?(## \[?{_VERSION_RE})",
        r"\1\n\n## [Unreleased]\n\n---\n\n\2",
        content,
        count=1,
    )

    changelog_path.write_text(content, encoding="utf-8")
    return True


# =============================================================================
# VERSION PROMPTING (cross-platform, with timeout)
# =============================================================================

# cspell:ignore kbhit getwch
# Version prompt split into helpers to keep cognitive complexity under limit (SonarQube).


def _handle_win_key(
    ch: str, buffer: list[str], default: str
) -> tuple[str | None, bool]:
    """Handle one Windows key; return (value to return or None, raise KeyboardInterrupt)."""
    if ch in ("\r", "\n"):
        return ("".join(buffer).strip() or default, False)
    if ch == "\x08":  # Backspace
        if buffer:
            buffer.pop()
            sys.stdout.write("\b \b")
            sys.stdout.flush()
        return (None, False)
    if ch == "\x03":  # Ctrl+C
        return (None, True)
    if ch.isprintable():
        buffer.append(ch)
        sys.stdout.write(ch)
        sys.stdout.flush()
    return (None, False)


def _prompt_version_windows(default: str, timeout: int) -> str:
    """Windows: editable pre-filled prompt; return buffer or default on Enter/timeout."""
    import msvcrt

    sys.stdout.write(f"  Version to publish: {default}")
    sys.stdout.flush()
    buffer = list(default)
    start = time.time()
    while time.time() - start < timeout:
        if not msvcrt.kbhit():
            time.sleep(0.05)
            continue
        ch = msvcrt.getwch()
        result, do_raise = _handle_win_key(ch, buffer, default)
        if do_raise:
            raise KeyboardInterrupt
        if result is not None:
            print()
            return result
        time.sleep(0.05)
    print()
    return "".join(buffer).strip() or default


def _prompt_version_unix(default: str, timeout: int) -> str:
    """Unix: readline with select-based timeout; [default] in brackets."""
    import select

    sys.stdout.write(f"  Version to publish [{default}]: ")
    sys.stdout.flush()
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if not ready:
        print()
        return default
    user_input = sys.stdin.readline().strip()
    return user_input if user_input else default


def prompt_version(default: str, timeout: int = 30) -> str:
    """Prompt for publish version with timeout.

    On Windows the default is pre-filled and editable.
    On Unix it is shown in brackets; press Enter to accept.
    Returns the default after *timeout* seconds of inactivity.
    """
    if sys.platform == "win32":
        return _prompt_version_windows(default, timeout)
    return _prompt_version_unix(default, timeout)


def prompt_version_until_valid(default_version: str) -> str:
    """Prompt for version until valid semver; return version string."""
    while True:
        version = prompt_version(default_version)
        if re.match(rf"^{_VERSION_RE}$", version):
            return version
        print_warning(
            f"Invalid version format '{version}'. "
            f"Use X.Y.Z or X.Y.Z-pre.N"
        )


# =============================================================================
# VERSION / CHANGELOG SYNCHRONIZATION
# =============================================================================


def apply_version_and_rename_unreleased(
    pubspec_path: Path,
    changelog_path: Path,
    pubspec_version: str,
    version: str,
) -> str:
    """Write version to pubspec and rename [Unreleased] in CHANGELOG; retry on conflict.

    Returns:
        The version string that was successfully synced.
    """
    version_to_sync = version
    while True:
        if version_to_sync != pubspec_version:
            set_version_in_pubspec(pubspec_path, version_to_sync)
            print_success(f"Updated pubspec.yaml to {version_to_sync}")
        try:
            if rename_unreleased_to_version(
                changelog_path, version_to_sync,
            ):
                print_success(
                    f"Renamed [Unreleased] to [{version_to_sync}] "
                    f"in CHANGELOG.md"
                )
            return version_to_sync
        except ValueError as exc:
            suggested = increment_version(version_to_sync)
            print_warning(str(exc))
            print_colored(
                f"  Suggested version: {suggested} (press Enter or edit)",
                Color.CYAN,
            )
            version_to_sync = prompt_version(suggested)
            if not re.match(rf"^{_VERSION_RE}$", version_to_sync):
                print_warning(
                    f"Invalid version format '{version_to_sync}'. "
                    f"Use X.Y.Z or X.Y.Z-pre.N"
                )


def reconcile_pubspec_changelog_versions(
    pubspec_path: Path,
    changelog_path: Path,
    version_to_sync: str,
) -> str:
    """Ensure pubspec and CHANGELOG versions match; exit on failure.

    Returns:
        The reconciled version string.
    """
    changelog_version = get_latest_changelog_version(changelog_path)
    if changelog_version is None:
        exit_with_error(
            "Could not extract version from CHANGELOG.md",
            ExitCode.CHANGELOG_FAILED,
        )
    if version_to_sync == changelog_version:
        return version_to_sync
    if parse_version(version_to_sync) < parse_version(changelog_version):
        print_warning(
            f"pubspec version ({version_to_sync}) is behind "
            f"CHANGELOG ({changelog_version}). Updating pubspec..."
        )
        set_version_in_pubspec(pubspec_path, changelog_version)
        print_success(f"Updated pubspec.yaml to {changelog_version}")
        return changelog_version
    print_warning(
        f"pubspec version ({version_to_sync}) is ahead "
        f"of CHANGELOG ({changelog_version})."
    )
    response = (
        input(
            f"  Add a [{version_to_sync}] section to "
            f"CHANGELOG.md? [Y/n] "
        )
        .strip()
        .lower()
    )
    if response.startswith("n"):
        exit_with_error(
            "Publish canceled — update CHANGELOG.md manually.",
            ExitCode.CHANGELOG_FAILED,
        )
    add_version_section(
        changelog_path, version_to_sync, "Version bump",
    )
    print_success(
        f"Added [{version_to_sync}] section to CHANGELOG.md"
    )
    return version_to_sync


def maybe_bump_for_tag_clash(
    project_dir: Path,
    pubspec_path: Path,
    changelog_path: Path,
    version_to_sync: str,
) -> str:
    """If tag v{version} exists on remote, bump version and add CHANGELOG section.

    Returns:
        The final version string (bumped if tag existed, unchanged otherwise).
    """
    tag_name = f"v{version_to_sync}"
    if not tag_exists_on_remote(project_dir, tag_name):
        return version_to_sync
    next_version = increment_version(version_to_sync)
    print_warning(
        f"Tag {tag_name} already exists on remote. "
        f"Version {version_to_sync} has already been published."
    )
    print_info(
        f"Bumping to {next_version} and adding CHANGELOG section."
    )
    set_version_in_pubspec(pubspec_path, next_version)
    add_version_section(
        changelog_path, next_version, "Release version",
    )
    print_success(
        f"Updated pubspec.yaml to {next_version} and added "
        f"[{next_version}] to CHANGELOG.md (Release version)."
    )
    return next_version


def sync_version_with_changelog(
    project_dir: Path,
    pubspec_path: Path,
    changelog_path: Path,
    pubspec_version: str,
    version: str,
) -> str:
    """Update pubspec/CHANGELOG with chosen version; reconcile; handle tag clash.

    Full version synchronization workflow:
    1. Apply version and rename [Unreleased] heading
    2. Reconcile any pubspec/CHANGELOG version mismatch
    3. Bump if the git tag already exists on remote

    Returns:
        The final resolved version string.
    """
    version_to_sync = apply_version_and_rename_unreleased(
        pubspec_path, changelog_path, pubspec_version, version,
    )
    version_to_sync = reconcile_pubspec_changelog_versions(
        pubspec_path, changelog_path, version_to_sync,
    )
    return maybe_bump_for_tag_clash(
        project_dir, pubspec_path, changelog_path, version_to_sync,
    )

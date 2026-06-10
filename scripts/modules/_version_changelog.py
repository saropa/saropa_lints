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


def find_empty_version_sections(changelog_path: Path) -> list[str]:
    """Return version numbers whose ``## [X.Y.Z]`` section has no body content.

    A section is "empty" if everything between its heading line and the next
    ``## `` heading (or EOF) consists of nothing but blank lines and ``---``
    separators. These stubs must never reach the publish path:

      * They cause ``rename_unreleased_to_version`` to raise on a perceived
        collision when the user chose the same version, which the loop then
        silently recovers from by suggesting the *next* patch — that is how
        v13.4.2 was skipped on its way to v13.4.3 (commit 0c5950aa wrote the
        empty stub; ``scripts/publish.py`` ran and jumped past it).
      * Even when no collision fires, the orphan stub lingers in the file
        forever between two real releases, implying a published version that
        never existed (no git tag, no pub.dev artifact).

    Returns the bare version strings (e.g. ``["13.4.2"]``); ``[Unreleased]``
    is intentionally NOT flagged here — emptiness on the unreleased header
    is the normal state right after a release.
    """
    if not changelog_path.exists():
        return []
    content = changelog_path.read_text(encoding="utf-8")
    # Match each `## [X.Y.Z]` heading and capture its body up to the next
    # `## ` heading or EOF. Headings inside HTML comment blocks would
    # match too, but the project's MAINTENANCE NOTES comment only quotes
    # `[Unreleased]` and not bare `## [X.Y.Z]` headings, so this is safe.
    pattern = re.compile(
        rf"^##\s*\[({_VERSION_RE})\][^\n]*\n(.*?)(?=^##\s|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    empty: list[str] = []
    for match in pattern.finditer(content):
        version = match.group(1)
        body = match.group(2)
        # Strip blank lines and `---` separator lines; whatever remains is
        # the real prose / bullets / details. Empty body == orphan stub.
        stripped = re.sub(r"^\s*(?:---\s*)?$", "", body, flags=re.MULTILINE)
        if not stripped.strip():
            empty.append(version)
    return empty


def assert_no_empty_changelog_sections(changelog_path: Path) -> None:
    """Abort the publish if CHANGELOG.md has any empty ``## [X.Y.Z]`` sections.

    Guards against the silent-skip class of bugs described in
    ``find_empty_version_sections``. The recovery is always manual — the
    author needs to either delete the stub (if it was never released) or
    fill in its release notes — so we exit hard rather than auto-edit.
    """
    empty = find_empty_version_sections(changelog_path)
    if not empty:
        return
    versions = ", ".join(f"[{v}]" for v in empty)
    print_warning(
        f"CHANGELOG.md has {len(empty)} empty version section(s): {versions}. "
        f"Empty stubs cause publish-time rename collisions and silent "
        f"version skips (see find_empty_version_sections doc). Either delete "
        f"the stub (if the version was never released) or fill in its "
        f"release notes before re-running publish."
    )
    exit_with_error(
        "Empty version section(s) in CHANGELOG.md — fix manually and retry.",
        ExitCode.CHANGELOG_FAILED,
    )


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


def _extract_changelog_section_body(
    content: str, version: str
) -> str | None:
    """Return the raw body of the ``## [version]`` section, or None if absent.

    Body = everything between the heading line and the next ``## [X.Y.Z]``
    heading (or EOF). Unlike ``validate_changelog_version`` this does NOT
    strip, because the Overview check needs to see the prose that sits
    before the first ``### `` sub-heading exactly as authored.
    """
    pattern = (
        rf"(?s)##\s*\[?{re.escape(version)}\]?[^\n]*\n"
        rf"(.*?)(?=##\s*\[?{_VERSION_RE}|$)"
    )
    match = re.search(pattern, content)
    return match.group(1) if match else None


def check_changelog_overview(
    changelog_path: Path, version: str
) -> list[str]:
    """Validate the ``[version]`` section's Overview intro and ``[log]`` link.

    Every released section opens with a user-facing Overview paragraph that
    ends in a ``[log](.../vX.Y.Z/CHANGELOG.md)`` link pinned to THIS version's
    git tag (see CHANGELOG.md MAINTENANCE NOTES). A missing intro ships a
    release with no human-readable summary; a stale/wrong version in the link
    points readers at the wrong tag snapshot.

    Returns:
        A list of human-readable problems; an empty list means the section is
        valid. ``version`` is the proposed publish version — the link must
        carry ``v{version}``, not ``main`` or any prior tag.
    """
    if not changelog_path.exists():
        return ["CHANGELOG.md not found."]
    content = changelog_path.read_text(encoding="utf-8")
    body = _extract_changelog_section_body(content, version)
    if body is None:
        return [f"No [{version}] section found in CHANGELOG.md."]

    # Overview = the prose before the first ### sub-heading. Drop a leading
    # `---` separator line that can sit between the heading and the body.
    intro = body.split("\n###", 1)[0]
    intro = re.sub(r"^\s*-{3,}\s*$", "", intro, flags=re.MULTILINE).strip()

    expected_link = (
        f"[log](https://github.com/saropa/saropa_lints/blob/"
        f"v{version}/CHANGELOG.md)"
    )
    log_match = re.search(r"\[log\]\(([^)]+)\)", intro)
    # Prose remaining once the link is removed — distinguishes "intro missing"
    # from "link present but no summary text".
    intro_prose = re.sub(r"\[log\]\([^)]*\)", "", intro).strip()

    problems: list[str] = []
    if not intro_prose:
        problems.append(
            f"The [{version}] section has no Overview intro paragraph "
            "(a 2-4 sentence user-facing summary above the ### bullets)."
        )
    if log_match is None:
        problems.append(
            f"The [{version}] Overview has no [log](...) link. "
            f"End it with: {expected_link}"
        )
    elif f"/blob/v{version}/" not in log_match.group(1):
        problems.append(
            f"The [{version}] [log] link does not point at tag v{version}. "
            f"Found: {log_match.group(0)} -- expected: {expected_link}"
        )
    return problems


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


def has_unreleased_section(changelog_path: Path) -> bool:
    """Return True if CHANGELOG.md has a ``## [Unreleased]`` heading.

    Used by the publish prompt to decide the default version offered:
    presence of an Unreleased section is the signal that there is real
    work pending against the last-published pubspec version, so the
    default should be ``increment_version(pubspec_version)``. Without
    an Unreleased section the prompt keeps the current pubspec value
    (which equals the last-published version) — that lands the user at
    a known-bad default for accidental publish runs and forces an
    explicit override when they really do mean to ship something.

    Matches the same literal pattern as ``rename_unreleased_to_version``
    so detection and renaming cannot diverge. Returns False on a missing
    file rather than raising, because the caller is a default-suggester
    and a missing CHANGELOG is a publish-blocker handled elsewhere.
    """
    if not changelog_path.is_file():
        return False
    content = changelog_path.read_text(encoding="utf-8")
    return bool(re.search(r"## \[Unreleased\]", content))


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
    """If tag v{version} exists on remote, bump version and PROMOTE the top
    CHANGELOG section to the new version (filename ⇔ CHANGELOG sync).

    The publish artifact (`.vsix` filename, `pubspec.yaml` version, git tag,
    Marketplace listing) and the top CHANGELOG section MUST carry the same
    version — otherwise users see release notes that do not match the version
    they install. When the colliding tag is detected we therefore RENAME the
    existing top section, never insert a placeholder "Release version" stub
    (the prior behavior shipped meaningless notes for v13.11.9 — see
    `plans/history/2026.06/2026.06.02/infra_publish_tag_clash_stub.md`).

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
        f"Bumping to {next_version} and promoting top CHANGELOG section."
    )
    set_version_in_pubspec(pubspec_path, next_version)
    promoted_from = _promote_top_section_to_version(
        changelog_path, version_to_sync, next_version,
    )
    if promoted_from is None:
        # Refuse to insert a stub — the top section is something the script
        # can't safely repurpose (e.g. a manually-edited future version or
        # no version section at all). The user must add real [next_version]
        # notes by hand so the .vsix filename matches the CHANGELOG.
        exit_with_error(
            f"Cannot publish [{next_version}]: top CHANGELOG section is "
            f"neither [{version_to_sync}] nor [Unreleased], so the script "
            f"won't auto-rename it. The published version, .vsix filename, "
            f"and top CHANGELOG section MUST be in sync. Manually add a "
            f"[{next_version}] section above the current top section with "
            f"real release notes, then re-run.",
            ExitCode.CHANGELOG_FAILED,
        )
    print_success(
        f"Updated pubspec.yaml to {next_version} and renamed top CHANGELOG "
        f"section [{promoted_from}] → [{next_version}]."
    )
    return next_version


def _promote_top_section_to_version(
    changelog_path: Path, expected_version: str, next_version: str,
) -> str | None:
    """Rename the top `## [X]` heading to `## [next_version]` when X is the
    expected colliding version or [Unreleased].

    Returns the original heading label on success, None when the top section
    is something else (caller should abort rather than guess).
    """
    content = changelog_path.read_text(encoding="utf-8")
    # Match the first ## [...] heading anywhere in the file — there are no
    # version-like headings before the first release section in this repo's
    # CHANGELOG layout (the header block uses no `## [...]` form).
    match = re.search(r"## \[([^\]]+)\]", content)
    if not match:
        return None
    label = match.group(1)
    if label != expected_version and label != "Unreleased":
        return None
    # Refuse if the target version already has its own section — caller's
    # abort path is safer than silently merging two histories.
    if re.search(rf"## \[{re.escape(next_version)}\]", content):
        return None
    new_content = (
        content[: match.start()]
        + f"## [{next_version}]"
        + content[match.end() :]
    )
    changelog_path.write_text(new_content, encoding="utf-8")
    return label


def sync_version_with_changelog(
    project_dir: Path,
    pubspec_path: Path,
    changelog_path: Path,
    pubspec_version: str,
    version: str,
) -> str:
    """Update pubspec/CHANGELOG with chosen version; reconcile; handle tag clash.

    Full version synchronization workflow:
    0. Refuse to proceed if any ``## [X.Y.Z]`` section is empty (silent-skip guard)
    1. Apply version and rename [Unreleased] heading
    2. Reconcile any pubspec/CHANGELOG version mismatch
    3. Bump if the git tag already exists on remote

    Returns:
        The final resolved version string.
    """
    # Guard upstream of every rename / reconcile path — an orphan empty
    # `## [X.Y.Z]` stub is exactly what let v13.4.2 get skipped past during
    # the v13.4.3 publish (the rename collision triggered the auto-suggest-
    # next-patch recovery in apply_version_and_rename_unreleased).
    assert_no_empty_changelog_sections(changelog_path)
    version_to_sync = apply_version_and_rename_unreleased(
        pubspec_path, changelog_path, pubspec_version, version,
    )
    version_to_sync = reconcile_pubspec_changelog_versions(
        pubspec_path, changelog_path, version_to_sync,
    )
    return maybe_bump_for_tag_clash(
        project_dir, pubspec_path, changelog_path, version_to_sync,
    )

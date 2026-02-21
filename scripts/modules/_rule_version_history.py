"""
Extract rule version history from changelogs and git history.

Provides functions to:
- Extract all rule names from Dart LintCode definitions
- Scan CHANGELOG.md and CHANGELOG_ARCHIVE.md for rule mentions
- Scan git history for commits that touch each rule
- Map commits to release versions
- Compute a per-rule version number (v1, v2, ...)

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
RULES_DIR = PROJECT_ROOT / "lib" / "src" / "rules"
CHANGELOG_PATH = PROJECT_ROOT / "CHANGELOG.md"
CHANGELOG_ARCHIVE_PATH = PROJECT_ROOT / "CHANGELOG_ARCHIVE.md"
REPORTS_DIR = PROJECT_ROOT / "reports"
CACHE_DIR = REPORTS_DIR / "_cache"
CACHE_PATH = CACHE_DIR / "rule_version_cache.json"


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class RuleInfo:
    """Parsed rule from Dart source."""

    name: str
    problem_message: str
    source_file: str
    line_number: int


@dataclass
class ChangelogMention:
    """A mention of a rule in a changelog."""

    version: str
    section: str          # Added, Changed, Fixed, Deprecated, Removed
    context: str          # snippet of surrounding text


@dataclass
class GitMention:
    """A mention of a rule in git history."""

    commit_hash: str
    commit_message: str
    release_version: str  # mapped build version


@dataclass
class VersionInfo:
    """Computed version info for a rule."""

    rule_version: int = 1
    created_in: str = "unknown"
    last_updated_in: str = "unknown"
    source_file: str = ""
    events: list[dict] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Phase 1: Extract rule names from Dart source
# ---------------------------------------------------------------------------

def extract_all_rules() -> dict[str, RuleInfo]:
    """Parse all *_rules.dart files and return rule info keyed by name."""
    rules: dict[str, RuleInfo] = {}

    dart_files = list(RULES_DIR.rglob("*_rules.dart"))
    for dart_file in dart_files:
        file_rules = _extract_rules_from_file(dart_file)
        for rule in file_rules:
            rules[rule.name] = rule

    return rules


def _extract_rules_from_file(file_path: Path) -> list[RuleInfo]:
    """Extract LintCode definitions from a single Dart file."""
    results: list[RuleInfo] = []
    text = file_path.read_text(encoding="utf-8")
    lines = text.splitlines()

    i = 0
    while i < len(lines):
        line = lines[i]
        # Skip commented-out code
        if line.strip().startswith("//"):
            i += 1
            continue
        if "LintCode(" in line:
            block_lines = [line]
            block_start = i
            paren_depth = line.count("(") - line.count(")")
            i += 1
            while i < len(lines) and paren_depth > 0:
                block_lines.append(lines[i])
                paren_depth += lines[i].count("(") - lines[i].count(")")
                i += 1
            block_text = "\n".join(block_lines)

            name = _extract_field(block_text, "name")
            problem = _extract_multiline_string(block_text, "problemMessage")

            if name:
                results.append(RuleInfo(
                    name=name,
                    problem_message=problem or "",
                    source_file=str(
                        file_path.relative_to(PROJECT_ROOT)
                    ).replace("\\", "/"),
                    line_number=block_start + 1,
                ))
        else:
            i += 1

    return results


def _extract_field(block: str, field_name: str) -> Optional[str]:
    """Extract a simple quoted string field from a LintCode block."""
    # Try single quotes first, then double quotes
    m = re.search(rf"{field_name}:\s*'([^']*)'", block)
    if m:
        return m.group(1)
    m = re.search(rf'{field_name}:\s*"([^"]*)"', block)
    return m.group(1) if m else None


def _extract_multiline_string(block: str, field_name: str) -> Optional[str]:
    """Extract a possibly multi-segment string field.

    Handles single-quoted, double-quoted, raw, and mixed concatenation.
    Uses collect_string_segments() for the actual parsing.
    """
    m = re.search(rf"{field_name}:\s*", block)
    if not m:
        return None

    segments, _ = collect_string_segments(block, m.end())
    return "".join(segments) if segments else None


def find_closing_quote(
    text: str, start: int, quote_char: str = "'", raw: bool = False
) -> int:
    """Find the closing quote, respecting backslash escapes.

    For raw strings (r'...' / r"..."), backslashes are literal.
    Public so version_rules.py can reuse without duplication.
    """
    i = start + 1
    while i < len(text):
        if not raw and text[i] == "\\" and i + 1 < len(text):
            i += 2  # skip escaped char
        elif text[i] == quote_char:
            return i
        else:
            i += 1
    return -1


def collect_string_segments(text: str, start: int) -> tuple[list[str], int]:
    """Parse consecutive Dart string segments from a position.

    Handles single-quoted, double-quoted, raw (r'...'), and
    multi-segment concatenation. Returns (segments, last_quote_end).
    last_quote_end is -1 if no segments were found.
    """
    pos = start
    segments: list[str] = []
    last_quote_end = -1

    while pos < len(text):
        while pos < len(text) and text[pos] in " \t\n\r":
            pos += 1
        if pos >= len(text):
            break

        is_raw = False
        if (
            text[pos] == "r"
            and pos + 1 < len(text)
            and text[pos + 1] in ("'", '"')
        ):
            is_raw = True
            pos += 1

        if text[pos] in ("'", '"'):
            quote_char = text[pos]
            close = find_closing_quote(text, pos, quote_char, raw=is_raw)
            if close == -1:
                break
            segments.append(text[pos + 1 : close])
            last_quote_end = close
            pos = close + 1
        else:
            break

    return segments, last_quote_end


# ---------------------------------------------------------------------------
# Phase 2: Scan changelogs
# ---------------------------------------------------------------------------

def scan_changelogs() -> dict[str, list[ChangelogMention]]:
    """Parse both changelog files for rule name mentions."""
    mentions: dict[str, list[ChangelogMention]] = {}

    for path in (CHANGELOG_PATH, CHANGELOG_ARCHIVE_PATH):
        if path.exists():
            file_mentions = _parse_changelog(path)
            for rule_name, rule_mentions in file_mentions.items():
                mentions.setdefault(rule_name, []).extend(rule_mentions)

    return mentions


def _parse_changelog(path: Path) -> dict[str, list[ChangelogMention]]:
    """Parse a single changelog file into rule mentions."""
    text = path.read_text(encoding="utf-8")
    mentions: dict[str, list[ChangelogMention]] = {}

    current_version = "unknown"
    current_section = "unknown"

    for line in text.splitlines():
        # Version header: ## [4.13.0]
        version_match = re.match(r"^##\s*\[(\d+\.\d+\.\d+)\]", line)
        if version_match:
            current_version = version_match.group(1)
            current_section = "unknown"
            continue

        # Section header: ### Added
        section_match = re.match(
            r"^###\s*(Added|Changed|Fixed|Deprecated|Removed)", line
        )
        if section_match:
            current_section = section_match.group(1)
            continue

        # Find backtick-quoted rule names
        backtick_names = re.findall(r"`([a-z][a-z0-9_]+)`", line)
        for name in backtick_names:
            if _looks_like_rule_name(name):
                mentions.setdefault(name, []).append(ChangelogMention(
                    version=current_version,
                    section=current_section,
                    context=line.strip()[:120],
                ))

        # Find bare rule names (avoid_xxx, prefer_xxx, require_xxx, no_xxx)
        bare_names = re.findall(
            r"\b((?:avoid|prefer|require|no|use|dispose|match|move|pass|"
            r"missing|function)_[a-z0-9_]+)\b",
            line,
        )
        for name in bare_names:
            if name not in backtick_names and _looks_like_rule_name(name):
                mentions.setdefault(name, []).append(ChangelogMention(
                    version=current_version,
                    section=current_section,
                    context=line.strip()[:120],
                ))

    return mentions


def _looks_like_rule_name(name: str) -> bool:
    """Heuristic: does this look like a lint rule name?"""
    if len(name) < 6:
        return False
    # Must have at least one underscore
    if "_" not in name:
        return False
    # Skip known non-rule patterns
    skip = {
        "ignore_for_file", "deprecated_member_use", "depend_on_referenced_packages",
        "custom_lint", "analysis_options", "error_severity", "source_range",
        "ignore_for_file", "pub_dev", "file_path", "rule_name",
    }
    return name not in skip


# ---------------------------------------------------------------------------
# Phase 3: Scan git history
# ---------------------------------------------------------------------------

def build_release_map() -> tuple[dict[str, str], list[tuple[str, str]]]:
    """Build commit-to-release-version mapping.

    Returns:
        (commit_to_version, releases) where releases is sorted
        oldest-first list of (hash, version).
    """
    result = subprocess.run(
        ["git", "log", "--oneline", "--all", "--grep=Release v"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(PROJECT_ROOT),
    )

    releases: list[tuple[str, str]] = []
    for line in result.stdout.strip().splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) < 2:
            continue
        commit_hash = parts[0]
        msg = parts[1]
        ver_match = re.search(r"v(\d+\.\d+\.\d+)", msg)
        if ver_match:
            releases.append((commit_hash, ver_match.group(1)))

    # Reverse to oldest-first
    releases.reverse()

    # Build full mapping: for each commit, find the next release
    commit_to_version: dict[str, str] = {}
    for h, v in releases:
        commit_to_version[h] = v

    return commit_to_version, releases


def _map_commit_to_version(
    commit_hash: str,
    release_commits: dict[str, str],
    all_releases: list[tuple[str, str]],
) -> str:
    """Map a commit hash to the release version it shipped in."""
    if commit_hash in release_commits:
        return release_commits[commit_hash]

    # Find which release contains this commit using git merge-base
    for rel_hash, rel_version in reversed(all_releases):
        result = subprocess.run(
            ["git", "merge-base", "--is-ancestor", commit_hash, rel_hash],
            capture_output=True, cwd=str(PROJECT_ROOT),
        )
        if result.returncode == 0:
            return rel_version

    return "unreleased"


def scan_git_history(
    rule_names: list[str],
    cache_path: Path = CACHE_PATH,
    skip_git: bool = False,
    verbose: bool = False,
    progress_callback=None,
) -> dict[str, list[GitMention]]:
    """Scan git history for mentions of each rule.

    Uses a fast batch approach: iterate all commits touching rule files
    once, extract rule names from each diff. Falls back to per-rule
    git log -S if batch is insufficient.
    """
    if skip_git and cache_path.exists():
        with cache_path.open("r", encoding="utf-8") as f:
            cached = json.load(f)
        result: dict[str, list[GitMention]] = {}
        for name, entries in cached.items():
            result[name] = [
                GitMention(
                    commit_hash=e["commit_hash"],
                    commit_message=e["commit_message"],
                    release_version=e["release_version"],
                )
                for e in entries
            ]
        return result

    rule_set = set(rule_names)
    release_commits, all_releases = build_release_map()

    # Build a fast commit -> version lookup using git rev-list
    commit_version_cache: dict[str, str] = {}

    mentions: dict[str, list[GitMention]] = {name: [] for name in rule_names}

    # --- Batch scan: process each commit's diff once ---
    print("  Batch scanning commits touching rule files...")
    commits = _get_commits_touching_rules()
    total = len(commits)
    print(f"  Processing {total} commits...")

    for idx, (commit_hash, commit_msg) in enumerate(commits):
        if verbose and (idx + 1) % 20 == 0:
            print(f"    [{idx + 1}/{total}] {commit_hash} {commit_msg[:50]}")

        # Get the diff for this commit (rule files + changelogs)
        diff_text = _get_commit_diff(commit_hash)

        # Map commit to release version (with caching)
        if commit_hash not in commit_version_cache:
            commit_version_cache[commit_hash] = _map_commit_to_version(
                commit_hash, release_commits, all_releases
            )
        version = commit_version_cache[commit_hash]

        # Find all rule names mentioned in the diff
        found = _find_rule_names_in_text(diff_text, rule_set)
        for rule_name in found:
            mentions[rule_name].append(GitMention(
                commit_hash=commit_hash,
                commit_message=commit_msg,
                release_version=version,
            ))

    # Cache results
    _save_git_cache(mentions, cache_path)

    return mentions


def _get_commits_touching_rules() -> list[tuple[str, str]]:
    """Get all commits that touch rule files or changelogs."""
    result = subprocess.run(
        [
            "git", "log", "--oneline", "--all",
            "--", "lib/src/rules/", "CHANGELOG.md", "CHANGELOG_ARCHIVE.md",
        ],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(PROJECT_ROOT), timeout=60,
    )
    commits: list[tuple[str, str]] = []
    for line in result.stdout.strip().splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) >= 2:
            commits.append((parts[0], parts[1]))
        elif len(parts) == 1:
            commits.append((parts[0], ""))
    return commits


def _get_commit_diff(commit_hash: str) -> str:
    """Get the diff text for a commit (rule files + changelogs only)."""
    result = subprocess.run(
        [
            "git", "diff-tree", "-p", "--no-commit-id",
            commit_hash,
            "--", "lib/src/rules/", "CHANGELOG.md", "CHANGELOG_ARCHIVE.md",
        ],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(PROJECT_ROOT), timeout=30,
    )
    return result.stdout or ""


def _find_rule_names_in_text(
    text: str, rule_set: set[str]
) -> set[str]:
    """Find all known rule names in a block of text."""
    found: set[str] = set()
    # Use a single regex to find all potential rule name tokens
    for m in re.finditer(r"[a-z][a-z0-9_]{5,}", text):
        token = m.group(0)
        if token in rule_set:
            found.add(token)
    return found


def _save_git_cache(
    mentions: dict[str, list[GitMention]], cache_path: Path
) -> None:
    """Save git mention data to JSON cache file."""
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    serializable = {
        name: [
            {
                "commit_hash": m.commit_hash,
                "commit_message": m.commit_message,
                "release_version": m.release_version,
            }
            for m in rule_mentions
        ]
        for name, rule_mentions in mentions.items()
    }
    with cache_path.open("w", encoding="utf-8") as f:
        json.dump(serializable, f, indent=2, ensure_ascii=False)


# ---------------------------------------------------------------------------
# Phase 4: Compute versions
# ---------------------------------------------------------------------------

def compute_versions(
    rules: dict[str, RuleInfo],
    changelog_mentions: dict[str, list[ChangelogMention]],
    git_mentions: dict[str, list[GitMention]],
) -> dict[str, VersionInfo]:
    """Merge changelog and git data to compute per-rule versions."""
    versions: dict[str, VersionInfo] = {}

    for rule_name, rule_info in rules.items():
        # Collect all unique build versions where this rule was touched
        version_events: dict[str, dict] = {}

        # From changelog
        for mention in changelog_mentions.get(rule_name, []):
            key = mention.version
            if key not in version_events:
                version_events[key] = {
                    "version": mention.version,
                    "type": mention.section,
                    "source": "changelog",
                }
            else:
                # Prefer higher-priority section type
                priority = {"Added": 5, "Changed": 4, "Fixed": 3,
                            "Deprecated": 2, "Removed": 1, "unknown": 0}
                existing = priority.get(version_events[key]["type"], 0)
                new = priority.get(mention.section, 0)
                if new > existing:
                    version_events[key]["type"] = mention.section

        # From git
        for mention in git_mentions.get(rule_name, []):
            key = mention.release_version
            if key not in version_events:
                version_events[key] = {
                    "version": mention.release_version,
                    "type": "Modified",
                    "source": "git",
                }
            # If already in changelog for same version, mark as both
            elif version_events[key]["source"] == "changelog":
                version_events[key]["source"] = "both"

        events = sorted(
            version_events.values(),
            key=lambda e: _version_sort_key(e["version"]),
        )

        # Determine created_in and last_updated_in
        created_in = "unknown"
        last_updated_in = "unknown"

        if events:
            # Find earliest "Added" event, or just earliest event
            added_events = [e for e in events if e["type"] == "Added"]
            if added_events:
                created_in = added_events[0]["version"]
            else:
                created_in = events[0]["version"]

            # Use last released version (skip "unreleased"/"unknown")
            released = [
                e for e in events
                if e["version"] not in ("unreleased", "unknown")
            ]
            if released:
                last_updated_in = released[-1]["version"]
            else:
                last_updated_in = events[-1]["version"]

        rule_version = max(1, len(events))

        versions[rule_name] = VersionInfo(
            rule_version=rule_version,
            created_in=created_in,
            last_updated_in=last_updated_in,
            source_file=rule_info.source_file,
            events=events,
        )

    return versions


def _version_sort_key(version_str: str) -> tuple[int, ...]:
    """Convert version string to sortable tuple."""
    if version_str in ("unknown", "unreleased"):
        return (9999, 9999, 9999)
    parts = version_str.split(".")
    try:
        return tuple(int(p) for p in parts)
    except ValueError:
        return (9999, 9999, 9999)

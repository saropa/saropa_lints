#!/usr/bin/env python3
"""
Assign version numbers to every lint rule based on changelog and git history.

Scans CHANGELOG.md, CHANGELOG_ARCHIVE.md, and git history to determine:
  - When each rule was created (build version)
  - When each rule was last updated (build version)
  - How many times each rule was modified (rule version: v1, v2, ...)

Then updates every rule's problemMessage with a {vN} suffix and adds
provenance to the DartDoc header.

Usage:
    python scripts/version_rules.py                 # Full run
    python scripts/version_rules.py --dry-run       # Preview changes
    python scripts/version_rules.py --report-only   # Reports only
    python scripts/version_rules.py --skip-git      # Use cached git data
    python scripts/version_rules.py --verbose        # Detailed progress

Exit Codes:
    0  - Success
    1  - No rules found
    2  - Validation failed
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path

# Ensure scripts/ is on path for module imports
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from modules._rule_version_history import (
    CACHE_PATH,
    PROJECT_ROOT,
    REPORTS_DIR,
    RULES_DIR,
    RuleInfo,
    VersionInfo,
    collect_string_segments,
    compute_versions,
    extract_all_rules,
    find_closing_quote,
    scan_changelogs,
    scan_git_history,
)
from modules._utils import Color, enable_ansi_support

SCRIPT_VERSION = "1.0"

# Color helpers for console output
_R = Color.RESET.value
_RED = Color.RED.value
_YEL = Color.YELLOW.value
_GRN = Color.GREEN.value
_CYN = Color.CYAN.value
_DIM = Color.DIM.value
_BLD = Color.BOLD.value


# ---------------------------------------------------------------------------
# Phase 5: Modify Dart source files
# ---------------------------------------------------------------------------

def update_dart_files(
    rules: dict[str, RuleInfo],
    versions: dict[str, VersionInfo],
    dry_run: bool = False,
    verbose: bool = False,
) -> dict[str, list[str]]:
    """Update problemMessage and DartDoc in all rule files.

    Returns a dict of {file_path: [changes_made]}.
    """
    # Group rules by source file
    rules_by_file: dict[str, list[str]] = {}
    for rule_name, rule_info in rules.items():
        rules_by_file.setdefault(rule_info.source_file, []).append(rule_name)

    changes: dict[str, list[str]] = {}

    for rel_path, rule_names in sorted(rules_by_file.items()):
        abs_path = PROJECT_ROOT / rel_path
        if not abs_path.exists():
            print(f"  WARNING: {rel_path} not found, skipping")
            continue

        text = abs_path.read_text(encoding="utf-8")
        original = text

        for rule_name in rule_names:
            version_info = versions.get(rule_name)
            if not version_info:
                continue

            tag = f"{{v{version_info.rule_version}}}"
            provenance = _build_provenance_line(version_info)

            # --- Update problemMessage ---
            text = _inject_version_tag(text, rule_name, tag)

            # --- Update DartDoc header ---
            text = _inject_provenance(text, rule_name, provenance)

        if text != original:
            file_changes = _diff_summary(original, text, rule_names, versions)
            changes[rel_path] = file_changes

            if verbose:
                for c in file_changes:
                    print(f"  {rel_path}: {c}")

            if not dry_run:
                abs_path.write_text(text, encoding="utf-8")

    return changes


def _format_version(version: str) -> str:
    """Format a version string, prefixing 'v' only for actual versions."""
    if version in ("unknown", "unreleased"):
        return version
    return f"v{version}"


def _build_provenance_line(info: VersionInfo) -> str:
    """Build the DartDoc provenance line."""
    parts = [f"Since: {_format_version(info.created_in)}"]
    if info.last_updated_in != info.created_in:
        parts.append(f"Updated: {_format_version(info.last_updated_in)}")
    parts.append(f"Rule version: v{info.rule_version}")
    return " | ".join(parts)


def _inject_version_tag(text: str, rule_name: str, tag: str) -> str:
    """Append {vN} to the end of a rule's problemMessage string.

    Handles single-quoted, double-quoted, and multi-segment strings.
    Finds ALL LintCode definitions for the given rule name and updates
    each one (some rules have multiple LintCode variants).
    Removes any existing {vN} tag first.
    """
    name_pattern = rf"name:\s*['\"]({re.escape(rule_name)})['\"]"

    # Process all occurrences (from last to first to preserve offsets)
    matches = list(re.finditer(name_pattern, text))
    for name_match in reversed(matches):
        text = _inject_tag_at_match(text, name_match, tag)

    return text


def _inject_tag_at_match(
    text: str, name_match: re.Match, tag: str
) -> str:
    """Inject a version tag into the problemMessage near a name match."""
    search_start = name_match.start()
    search_region = text[search_start : search_start + 2000]

    pm_match = re.search(r"problemMessage:\s*\n?\s*", search_region)
    if not pm_match:
        return text

    pm_start = search_start + pm_match.end()

    # Skip if the problemMessage starts with string interpolation
    next_chars = text[pm_start : pm_start + 5]
    if next_chars.startswith("'$") or next_chars.startswith('"$'):
        return text

    segments, last_quote_end = collect_string_segments(text, pm_start)

    if last_quote_end == -1:
        return text

    # Skip if any segment contains interpolation
    if any("${" in seg for seg in segments):
        return text

    # Remove any existing {vN} tag
    before_quote = text[search_start:last_quote_end]
    tag_match = re.search(r"\s*\{v\d+\}\s*$", before_quote)

    if tag_match:
        remove_start = search_start + tag_match.start()
        text = text[:remove_start] + text[last_quote_end:]
        last_quote_end = remove_start

    # Insert new tag before closing quote
    text = text[:last_quote_end] + f" {tag}" + text[last_quote_end:]

    return text


def _inject_provenance(text: str, rule_name: str, provenance: str) -> str:
    """Insert or update provenance line in the DartDoc header above the rule class."""
    # Find the class declaration for this rule
    class_pattern = rf"class\s+\w+\s+extends\s+\w+.*?\{{"
    # We need to find the class that uses this rule's LintCode
    name_pattern = rf"name:\s*'{re.escape(rule_name)}'"
    name_match = re.search(name_pattern, text)
    if not name_match:
        return text

    # Search backwards from name to find the class declaration
    search_region = text[:name_match.start()]
    class_matches = list(re.finditer(
        r"class\s+(\w+)\s+extends\s+\w+", search_region
    ))
    if not class_matches:
        return text

    class_match = class_matches[-1]  # closest class before the name
    class_start = class_match.start()

    # Find the DartDoc block above the class
    # Search backwards from class_start for consecutive /// lines
    lines_before = text[:class_start].rstrip()
    lines_list = lines_before.split("\n")

    # Find the last line of DartDoc (should be right before class)
    doc_end_idx = len(lines_list) - 1
    while doc_end_idx >= 0 and not lines_list[doc_end_idx].strip():
        doc_end_idx -= 1

    if doc_end_idx < 0 or not lines_list[doc_end_idx].strip().startswith("///"):
        return text

    # Find the start of the DartDoc block
    doc_start_idx = doc_end_idx
    while doc_start_idx > 0 and lines_list[doc_start_idx - 1].strip().startswith("///"):
        doc_start_idx -= 1

    # Remove any existing provenance line
    provenance_prefix = "/// Since:"
    cleaned_lines = [
        l for l in lines_list[doc_start_idx:doc_end_idx + 1]
        if not l.strip().startswith(provenance_prefix)
    ]

    # Insert provenance after the first /// line (the brief description)
    if len(cleaned_lines) >= 2:
        insert_pos = 1  # after first line
        # If second line is empty (///), insert after it
        if cleaned_lines[1].strip() == "///":
            insert_pos = 2
    else:
        insert_pos = 1

    new_provenance_line = f"/// {provenance}"

    # Check if we need a blank /// before/after
    needs_blank_before = (
        insert_pos > 0
        and cleaned_lines[insert_pos - 1].strip() != "///"
        and cleaned_lines[insert_pos - 1].strip() != "/// " + provenance
    )
    needs_blank_after = (
        insert_pos < len(cleaned_lines)
        and cleaned_lines[insert_pos].strip() != "///"
    )

    insert_block = []
    if needs_blank_before:
        insert_block.append("///")
    insert_block.append(new_provenance_line)
    if needs_blank_after:
        insert_block.append("///")

    new_doc = (
        cleaned_lines[:insert_pos]
        + insert_block
        + cleaned_lines[insert_pos:]
    )

    # Rebuild the text
    rebuilt = (
        "\n".join(lines_list[:doc_start_idx])
        + ("\n" if doc_start_idx > 0 else "")
        + "\n".join(new_doc)
        + "\n"
        + text[class_start:]
    )

    return rebuilt


def _diff_summary(
    original: str,
    modified: str,
    rule_names: list[str],
    versions: dict[str, VersionInfo],
) -> list[str]:
    """Summarize changes made to a file."""
    changes = []
    for name in rule_names:
        v = versions.get(name)
        if v:
            changes.append(
                f"{name}: v{v.rule_version} "
                f"(created {v.created_in}, updated {v.last_updated_in})"
            )
    return changes


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

def generate_json_report(
    versions: dict[str, VersionInfo], path: Path
) -> None:
    """Write full version history to JSON."""
    data = {}
    for name, info in sorted(versions.items()):
        data[name] = {
            "rule_version": info.rule_version,
            "created_in": info.created_in,
            "last_updated_in": info.last_updated_in,
            "source_file": info.source_file,
            "events": info.events,
        }

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"  JSON report: {path}")


def generate_summary_report(
    versions: dict[str, VersionInfo],
    rules: dict[str, RuleInfo],
    path: Path,
) -> None:
    """Write human-readable summary including gaps."""
    total = len(versions)
    if total == 0:
        return

    # Version distribution
    dist: dict[int, int] = {}
    for info in versions.values():
        dist[info.rule_version] = dist.get(info.rule_version, 0) + 1

    # Top modified
    top = sorted(
        versions.items(),
        key=lambda x: x[1].rule_version,
        reverse=True,
    )[:20]

    # Gaps: rules with missing data
    no_version_tag = _find_rules_without_version_tag(rules)
    unknown_created = [
        (n, v) for n, v in versions.items() if v.created_in == "unknown"
    ]
    no_events = [
        (n, v) for n, v in versions.items() if not v.events
    ]
    unreleased = [
        (n, v) for n, v in versions.items()
        if v.last_updated_in == "unreleased"
    ]

    lines = [
        "Rule Versioning Summary",
        "=" * 60,
        f"Total rules:       {total}",
        "",
        "Version distribution:",
    ]

    for v in sorted(dist.keys()):
        count = dist[v]
        pct = count / total * 100
        bar = "#" * max(1, int(pct / 2))
        lines.append(f"  v{v:<4} {count:>5} ({pct:5.1f}%)  {bar}")

    lines.append("")
    lines.append(f"Top {len(top)} most-modified rules:")
    for name, info in top:
        lines.append(
            f"  {name:<55} v{info.rule_version:<3} "
            f"(created {info.created_in}, updated {info.last_updated_in})"
        )

    # --- Gaps section ---
    lines.append("")
    lines.append("=" * 60)
    lines.append("GAPS: Rules with missing data")
    lines.append("=" * 60)

    gap_count = (
        len(no_version_tag) + len(unknown_created)
        + len(no_events) + len(unreleased)
    )

    if gap_count == 0:
        lines.append("  None - all rules have complete data.")
    else:
        if no_version_tag:
            lines.append("")
            lines.append(
                f"Rules without {{vN}} tag in problemMessage "
                f"({len(no_version_tag)}):"
            )
            for name, reason in sorted(no_version_tag):
                src = rules[name].source_file if name in rules else "?"
                lines.append(f"  {name:<55} {src:<40} {reason}")

        if unknown_created:
            lines.append("")
            lines.append(
                f"Rules with unknown created date ({len(unknown_created)}):"
            )
            for name, info in sorted(unknown_created):
                lines.append(
                    f"  {name:<55} {info.source_file}"
                )

        if unreleased:
            lines.append("")
            lines.append(
                f"Rules only in unreleased commits ({len(unreleased)}):"
            )
            for name, info in sorted(unreleased):
                lines.append(
                    f"  {name:<55} {info.source_file}"
                )

        if no_events:
            lines.append("")
            lines.append(
                f"Rules with no changelog or git history "
                f"({len(no_events)}):"
            )
            for name, info in sorted(no_events):
                lines.append(
                    f"  {name:<55} {info.source_file}"
                )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"  Summary report: {path}")


def _find_rules_without_version_tag(
    rules: dict[str, RuleInfo],
) -> list[tuple[str, str]]:
    """Scan Dart source files for rules missing {vN} in problemMessage.

    Returns list of (rule_name, reason) tuples.
    """
    missing: list[tuple[str, str]] = []

    # Group rules by file and read each file once
    by_file: dict[str, list[str]] = {}
    for name, info in rules.items():
        by_file.setdefault(info.source_file, []).append(name)

    for rel_path, names in by_file.items():
        abs_path = PROJECT_ROOT / rel_path
        if not abs_path.exists():
            for name in names:
                missing.append((name, "file not found"))
            continue

        text = abs_path.read_text(encoding="utf-8")

        for name in names:
            pattern = rf"name:\s*['\"]({re.escape(name)})['\"]"
            matches = list(re.finditer(pattern, text))
            if not matches:
                missing.append((name, "LintCode not found in file"))
                continue

            found_tag = False
            all_dynamic = True
            for m in matches:
                # Extract the full problemMessage string content
                full_msg = _extract_problem_message_at(text, m.start())
                if full_msg is None:
                    continue
                if "${" in full_msg:
                    continue  # dynamic interpolation
                all_dynamic = False
                if re.search(r"\{v\d+\}", full_msg):
                    found_tag = True
                    break

            if all_dynamic:
                continue
            if not found_tag:
                missing.append((name, "no {vN} in problemMessage"))

    return missing


def _extract_problem_message_at(text: str, name_start: int) -> str | None:
    """Extract the full problemMessage string near a name: match."""
    region = text[name_start : name_start + 2000]
    pm = re.search(r"problemMessage:\s*\n?\s*", region)
    if not pm:
        return None

    segments, _ = collect_string_segments(text, name_start + pm.end())
    return "".join(segments) if segments else None


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def validate_results(rules: dict[str, RuleInfo]) -> list[str]:
    """Re-extract rules and verify version tags are present.

    Skips rules that have:
    - Empty problemMessage (commented-out or dynamic interpolation)
    - String interpolation (${ or $var) in the message
    """
    fresh = extract_all_rules()
    errors = []

    for name, info in fresh.items():
        msg = info.problem_message

        # Skip rules with empty messages (commented-out code or
        # dynamic LintCode with string interpolation)
        if not msg:
            continue

        # Skip rules whose message contains interpolation markers
        # (these are dynamic LintCode instances we can't modify)
        if "${" in msg or "\\$" in msg:
            continue

        if not re.search(r"\{v\d+\}", msg):
            errors.append(f"{name}: missing {{vN}} tag in problemMessage")

        # Check for duplicate tags
        tags = re.findall(r"\{v\d+\}", msg)
        if len(tags) > 1:
            errors.append(f"{name}: duplicate version tags: {tags}")

        # Check [rule_name] prefix still intact
        if not msg.startswith(f"[{name}]"):
            errors.append(f"{name}: missing [{name}] prefix")

    return errors


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Assign version numbers to lint rules.",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show changes without modifying files",
    )
    parser.add_argument(
        "--skip-git", action="store_true",
        help="Use cached git data for faster reruns",
    )
    parser.add_argument(
        "--report-only", action="store_true",
        help="Generate reports without modifying Dart files",
    )
    parser.add_argument(
        "--verbose", action="store_true",
        help="Show progress for each rule",
    )
    parser.add_argument(
        "--cache-file", type=Path, default=CACHE_PATH,
        help="Override cache file location",
    )
    args = parser.parse_args()

    enable_ansi_support()

    print(f"{_BLD}Rule Versioning Script v{SCRIPT_VERSION}{_R}")
    print("=" * 60)

    # Phase 1: Extract rules
    print(f"\n{_CYN}Phase 1: Extracting rules from Dart source...{_R}")
    start = time.time()
    rules = extract_all_rules()
    print(f"  Found {_BLD}{len(rules)}{_R} rules in {time.time() - start:.1f}s")

    if not rules:
        print(f"  {_RED}ERROR: No rules found!{_R}")
        return 1

    # Phase 2: Scan changelogs
    print(f"\n{_CYN}Phase 2: Scanning changelogs...{_R}")
    start = time.time()
    changelog_mentions = scan_changelogs()
    rules_in_changelog = sum(
        1 for name in rules if name in changelog_mentions
    )
    print(
        f"  Found mentions for {_BLD}{rules_in_changelog}/{len(rules)}{_R} "
        f"rules in {time.time() - start:.1f}s"
    )

    # Phase 3: Scan git history
    print(f"\n{_CYN}Phase 3: Scanning git history...{_R}")
    if args.skip_git and args.cache_file.exists():
        print(f"  {_DIM}Using cached data...{_R}")
    else:
        print(
            f"  Scanning {len(rules)} rules "
            f"{_DIM}(this may take a few minutes)...{_R}"
        )
    start = time.time()
    git_mentions = scan_git_history(
        list(rules.keys()),
        cache_path=args.cache_file,
        skip_git=args.skip_git,
        verbose=args.verbose,
    )
    rules_in_git = sum(
        1 for name in rules if name in git_mentions and git_mentions[name]
    )
    print(
        f"  Found mentions for {_BLD}{rules_in_git}/{len(rules)}{_R} "
        f"rules in {time.time() - start:.1f}s"
    )

    # Phase 4: Compute versions
    print(f"\n{_CYN}Phase 4: Computing rule versions...{_R}")
    start = time.time()
    versions = compute_versions(rules, changelog_mentions, git_mentions)
    print(f"  Computed versions in {time.time() - start:.1f}s")

    # Generate version data report (before file modifications)
    print(f"\n{_CYN}Generating reports...{_R}")
    file_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    date_folder = file_timestamp[:8]
    dated_dir = REPORTS_DIR / date_folder
    dated_dir.mkdir(parents=True, exist_ok=True)
    json_path = dated_dir / f"{file_timestamp}_rule_versions.json"
    summary_path = dated_dir / f"{file_timestamp}_rule_versions_summary.txt"
    generate_json_report(versions, json_path)

    # Phase 5: Update Dart files
    if args.report_only:
        print(f"\n{_DIM}--report-only: skipping Dart file modifications{_R}")
    else:
        mode = f"{_YEL}DRY RUN{_R}" if args.dry_run else f"{_GRN}LIVE{_R}"
        print(f"\n{_CYN}Phase 5: Updating Dart files ({mode}{_CYN})...{_R}")
        start = time.time()
        changes = update_dart_files(
            rules, versions,
            dry_run=args.dry_run,
            verbose=args.verbose,
        )
        total_changes = sum(len(c) for c in changes.values())
        print(
            f"  Modified {_BLD}{len(changes)}{_R} files, "
            f"{_BLD}{total_changes}{_R} rules in {time.time() - start:.1f}s"
        )

        if not args.dry_run:
            print(f"\n{_CYN}Validating results...{_R}")
            errors = validate_results(rules)
            if errors:
                print(f"  {_RED}ERRORS ({len(errors)}):{_R}")
                for err in errors[:20]:
                    print(f"    {_RED}{err}{_R}")
                if len(errors) > 20:
                    print(f"    {_DIM}... and {len(errors) - 20} more{_R}")
                return 2
            else:
                print(f"  {_GRN}All rules validated successfully!{_R}")

    # Generate summary report (after modifications so gap scan is accurate)
    generate_summary_report(versions, rules, summary_path)

    # Print gaps to console with color
    _print_gaps_console(versions, rules)

    print(f"\n{_GRN}Done!{_R}")
    return 0


def _print_gaps_console(
    versions: dict[str, VersionInfo],
    rules: dict[str, RuleInfo],
) -> None:
    """Print colorized gaps summary to console."""
    no_version_tag = _find_rules_without_version_tag(rules)
    unknown_created = [
        (n, v) for n, v in versions.items() if v.created_in == "unknown"
    ]
    no_events = [
        (n, v) for n, v in versions.items() if not v.events
    ]
    unreleased = [
        (n, v) for n, v in versions.items()
        if v.last_updated_in == "unreleased"
    ]

    total_gaps = (
        len(no_version_tag) + len(unknown_created)
        + len(no_events) + len(unreleased)
    )

    if total_gaps == 0:
        print(f"\n{_GRN}No gaps: all rules have version tags and dates.{_R}")
        return

    print(f"\n{_YEL}{'=' * 60}{_R}")
    print(f"{_YEL}GAPS: Rules with missing data{_R}")
    print(f"{_YEL}{'=' * 60}{_R}")

    if no_version_tag:
        print(
            f"\n  {_RED}{len(no_version_tag)}{_R} rules "
            f"without {{vN}} tag in problemMessage:"
        )
        for name, reason in sorted(no_version_tag)[:20]:
            src = rules[name].source_file if name in rules else "?"
            print(f"    {_RED}{name:<50}{_R} {_DIM}{src}{_R}")
        if len(no_version_tag) > 20:
            print(
                f"    {_DIM}... and {len(no_version_tag) - 20} more{_R}"
            )

    if unknown_created:
        print(
            f"\n  {_YEL}{len(unknown_created)}{_R} rules "
            f"with unknown created date:"
        )
        for name, info in sorted(unknown_created)[:20]:
            print(f"    {_YEL}{name:<50}{_R} {_DIM}{info.source_file}{_R}")
        if len(unknown_created) > 20:
            print(
                f"    {_DIM}... and {len(unknown_created) - 20} more{_R}"
            )

    if unreleased:
        print(
            f"\n  {_YEL}{len(unreleased)}{_R} rules "
            f"only in unreleased commits:"
        )
        for name, info in sorted(unreleased)[:20]:
            print(f"    {_YEL}{name:<50}{_R} {_DIM}{info.source_file}{_R}")

    if no_events:
        print(
            f"\n  {_RED}{len(no_events)}{_R} rules "
            f"with no changelog or git history:"
        )
        for name, info in sorted(no_events)[:20]:
            print(f"    {_RED}{name:<50}{_R} {_DIM}{info.source_file}{_R}")


if __name__ == "__main__":
    sys.exit(main())

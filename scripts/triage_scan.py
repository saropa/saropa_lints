#!/usr/bin/env python3
"""
Auto-triage saropa_lints scan diagnostics into a prioritized fix queue.

Reads the JSON output of `dart run saropa_lints scan --format json` and
groups diagnostics into five priority buckets:

  1. Errors in app code — fix first
  2. Warnings/infos in app code, >= BULK_THRESHOLD sites from the same rule
     — one mechanical fix
  3. Warnings/infos in app code, fewer sites — individual triage
  4. Any severity in dev/debug directories — likely suppress
  5. Any severity in forked/vendored directories — suppress

Usage:
    dart run saropa_lints scan . --format json | python scripts/triage_scan.py
    python scripts/triage_scan.py --input scan_output.json
    python scripts/triage_scan.py --input scan.json --suppress-dirs vendor third_party
    python scripts/triage_scan.py --input scan.json --format json

Exit code 0 always (triage is advisory, not a gate).

Requires Python 3.10+ (uses X | Y union syntax in type hints).

Version:   1.1
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path, PurePosixPath

# Minimum Python version — the script uses 3.10+ union syntax (X | Y).
_MIN_PYTHON = (3, 10)
if sys.version_info < _MIN_PYTHON:
    sys.exit(
        f'triage_scan.py requires Python {_MIN_PYTHON[0]}.{_MIN_PYTHON[1]}+, '
        f'got {sys.version_info.major}.{sys.version_info.minor}.'
    )

# --- Constants ---------------------------------------------------------------

# Expected scan JSON schema version.  Warns (does not fail) on mismatch so
# the script degrades gracefully when the scan CLI evolves.
_EXPECTED_SCHEMA_VERSION = 1

# Directories whose diagnostics default to "suppress, don't fix".
_DEFAULT_FORKED_DIRS = {'dependency_overrides'}

# Directories whose diagnostics default to "likely suppress" (dev tooling).
_DEFAULT_DEV_DIRS = {'_dev', 'debug', '_developer'}

# Default minimum sites per rule to qualify as a bulk mechanical fix.
_DEFAULT_BULK_THRESHOLD = 5

# Severity ordering — higher rank = fix first.
_SEVERITY_RANK = {'ERROR': 3, 'WARNING': 2, 'INFO': 1}


# --- Path classification ----------------------------------------------------

def _normalize_path(file_path: str) -> str:
    """Normalize backslashes to forward slashes for consistent matching."""
    return file_path.replace('\\', '/')


def _path_matches_dir_set(file_path: str, dir_names: set[str]) -> bool:
    """True if any path segment matches one of the directory names."""
    parts = PurePosixPath(_normalize_path(file_path)).parts
    return bool(dir_names.intersection(parts))


def classify_location(
    file_path: str,
    forked_dirs: set[str],
    dev_dirs: set[str],
) -> str:
    """Classify a diagnostic's file into a location bucket.

    Returns one of: 'forked', 'dev', 'app'.
    """
    if _path_matches_dir_set(file_path, forked_dirs):
        return 'forked'
    if _path_matches_dir_set(file_path, dev_dirs):
        return 'dev'
    return 'app'


# --- Triage ------------------------------------------------------------------

def triage(
    diagnostics: list[dict],
    forked_dirs: set[str],
    dev_dirs: set[str],
    bulk_threshold: int = _DEFAULT_BULK_THRESHOLD,
) -> dict[str, list[dict]]:
    """Sort diagnostics into five priority buckets.

    Returns a dict keyed by bucket name, each value a list of diagnostics.
    """
    # Buckets: p1 errors, p2 bulk, p3 individual, p4 dev, p5 forked.
    buckets: dict[str, list[dict]] = {
        'p1_errors': [],
        'p2_bulk': [],
        'p3_individual': [],
        'p4_dev': [],
        'p5_forked': [],
    }

    # First pass: separate by location.
    app_diags: list[dict] = []
    for d in diagnostics:
        loc = classify_location(d.get('filePath', ''), forked_dirs, dev_dirs)
        if loc == 'forked':
            buckets['p5_forked'].append(d)
        elif loc == 'dev':
            buckets['p4_dev'].append(d)
        else:
            app_diags.append(d)

    # Second pass: split app diagnostics into errors vs warnings/infos.
    non_error_app: list[dict] = []
    for d in app_diags:
        sev = (d.get('severity') or '').upper()
        if sev == 'ERROR':
            buckets['p1_errors'].append(d)
        else:
            non_error_app.append(d)

    # Third pass: group non-error app diagnostics by rule to find bulk fixes.
    by_rule: dict[str, list[dict]] = defaultdict(list)
    for d in non_error_app:
        by_rule[d.get('ruleName', '<unknown>')].append(d)

    for rule_name, rule_diags in by_rule.items():
        if len(rule_diags) >= bulk_threshold:
            buckets['p2_bulk'].extend(rule_diags)
        else:
            buckets['p3_individual'].extend(rule_diags)

    return buckets


# --- Human-readable formatting -----------------------------------------------

def _file_basename(file_path: str) -> str:
    """Short display name: last path component."""
    return PurePosixPath(_normalize_path(file_path)).name


def _sev_tag(d: dict) -> str:
    """Format severity/impact for display."""
    sev = (d.get('severity') or 'UNKNOWN').upper()
    impact = d.get('impact')
    # Show impact alongside severity when available and different.
    if impact and impact.upper() != sev:
        return f'{sev} / impact {impact}'
    return sev


def _format_diag_line(d: dict) -> str:
    """Format a single diagnostic as a one-line summary."""
    name = _file_basename(d.get('filePath', '?'))
    line = d.get('line', '?')
    rule = d.get('ruleName', '?')
    return f'  - {name}:{line} — {rule} ({_sev_tag(d)})'


def _format_bulk_group(rule_name: str, diags: list[dict]) -> str:
    """Format a bulk-fix group: count + rule + correction hint."""
    # Use the first diagnostic's correction message as the action hint.
    hint = ''
    for d in diags:
        corr = d.get('correctionMessage')
        if corr:
            hint = f' — {corr}'
            break
    return f'  - [{len(diags)} sites] {rule_name}{hint}'


def _format_file_group(file_path: str, diags: list[dict]) -> str:
    """Format a file-grouped summary for dev/forked buckets."""
    name = _file_basename(file_path)
    count = len(diags)
    suffix = 'diagnostic' if count == 1 else 'diagnostics'
    return f'  - {name} — {count} {suffix}'


def format_report(buckets: dict[str, list[dict]], total: int) -> str:
    """Build the human-readable triage report."""
    lines: list[str] = []

    # Header with totals.
    lines.append(f'Diagnostic Triage Report — {total} total')
    lines.append('=' * 50)
    lines.append('')

    # P1: Errors in app code.
    p1 = buckets['p1_errors']
    lines.append(f'## Priority 1: Errors in app code — fix first ({len(p1)})')
    if p1:
        # Sort by file path for stable output.
        p1_sorted = sorted(p1, key=lambda d: d.get('filePath', ''))
        for d in p1_sorted:
            lines.append(_format_diag_line(d))
    else:
        lines.append('  (none)')
    lines.append('')

    # P2: Bulk mechanical fixes (same rule, >= threshold).
    p2 = buckets['p2_bulk']
    lines.append(
        f'## Priority 2: Warnings in app code — bulk mechanical fix ({len(p2)})'
    )
    if p2:
        # Group by rule for display.
        by_rule: dict[str, list[dict]] = defaultdict(list)
        for d in p2:
            by_rule[d.get('ruleName', '?')].append(d)
        for rule_name in sorted(by_rule):
            lines.append(_format_bulk_group(rule_name, by_rule[rule_name]))
    else:
        lines.append('  (none)')
    lines.append('')

    # P3: Individual triage.
    p3 = buckets['p3_individual']
    lines.append(
        f'## Priority 3: Warnings in app code — individual triage ({len(p3)})'
    )
    if p3:
        p3_sorted = sorted(
            p3,
            key=lambda d: (
                -_SEVERITY_RANK.get((d.get('severity') or '').upper(), 0),
                d.get('filePath', ''),
            ),
        )
        for d in p3_sorted:
            lines.append(_format_diag_line(d))
    else:
        lines.append('  (none)')
    lines.append('')

    # P4: Dev/debug code.
    p4 = buckets['p4_dev']
    lines.append(
        f'## Priority 4: Dev/debug code — likely suppress ({len(p4)})'
    )
    if p4:
        # Group by file for a compact view.
        by_file: dict[str, list[dict]] = defaultdict(list)
        for d in p4:
            by_file[d.get('filePath', '?')].append(d)
        for fp in sorted(by_file):
            lines.append(_format_file_group(fp, by_file[fp]))
    else:
        lines.append('  (none)')
    lines.append('')

    # P5: Forked/vendored code.
    p5 = buckets['p5_forked']
    lines.append(
        f'## Priority 5: Forked/vendored code — suppress ({len(p5)})'
    )
    if p5:
        by_file_forked: dict[str, list[dict]] = defaultdict(list)
        for d in p5:
            by_file_forked[d.get('filePath', '?')].append(d)
        for fp in sorted(by_file_forked):
            lines.append(_format_file_group(fp, by_file_forked[fp]))
    else:
        lines.append('  (none)')
    lines.append('')

    return '\n'.join(lines)


# --- JSON output -------------------------------------------------------------

def format_json(buckets: dict[str, list[dict]], total: int) -> str:
    """Build a machine-readable JSON triage report.

    Returns a pretty-printed JSON string with the same bucket structure
    the human report uses, plus per-bucket counts and the overall total.
    """
    # Build per-bucket summaries with counts and diagnostics.
    output: dict[str, object] = {
        'version': 1,
        'total': total,
        'buckets': {},
    }

    # Bucket metadata for JSON consumers.
    _BUCKET_META = {
        'p1_errors': {
            'label': 'Errors in app code',
            'action': 'fix',
        },
        'p2_bulk': {
            'label': 'Warnings in app code — bulk mechanical fix',
            'action': 'fix (bulk)',
        },
        'p3_individual': {
            'label': 'Warnings in app code — individual triage',
            'action': 'triage',
        },
        'p4_dev': {
            'label': 'Dev/debug code',
            'action': 'likely suppress',
        },
        'p5_forked': {
            'label': 'Forked/vendored code',
            'action': 'suppress',
        },
    }

    for key, diags in buckets.items():
        meta = _BUCKET_META.get(key, {})
        bucket_obj: dict[str, object] = {
            'label': meta.get('label', key),
            'action': meta.get('action', 'unknown'),
            'count': len(diags),
            'diagnostics': diags,
        }

        # For bulk buckets, add a by-rule grouping summary.
        if key == 'p2_bulk' and diags:
            by_rule: dict[str, int] = defaultdict(int)
            for d in diags:
                by_rule[d.get('ruleName', '?')] += 1
            bucket_obj['byRule'] = dict(sorted(by_rule.items()))

        # For dev/forked buckets, add a by-file grouping summary.
        if key in ('p4_dev', 'p5_forked') and diags:
            by_file: dict[str, int] = defaultdict(int)
            for d in diags:
                by_file[d.get('filePath', '?')] += 1
            bucket_obj['byFile'] = dict(sorted(by_file.items()))

        output['buckets'][key] = bucket_obj

    return json.dumps(output, indent=2)


# --- CLI entry point ---------------------------------------------------------

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description='Auto-triage saropa_lints scan JSON into priority buckets.',
    )
    parser.add_argument(
        '--input', '-i',
        help='Path to scan JSON file. Reads stdin if omitted.',
    )
    parser.add_argument(
        '--format', '-f',
        choices=['text', 'json'],
        default='text',
        help='Output format: text (default) or json.',
    )
    parser.add_argument(
        '--suppress-dirs',
        nargs='*',
        default=[],
        help='Extra directory names to treat as forked/suppress-by-default.',
    )
    parser.add_argument(
        '--dev-dirs',
        nargs='*',
        default=[],
        help='Extra directory names to treat as dev/debug (likely suppress).',
    )
    parser.add_argument(
        '--bulk-threshold',
        type=int,
        default=_DEFAULT_BULK_THRESHOLD,
        help=(
            'Min sites per rule to qualify as bulk fix '
            f'(default {_DEFAULT_BULK_THRESHOLD}).'
        ),
    )
    return parser.parse_args(argv)


def _load_scan_json(input_path: str | None) -> dict:
    """Load and validate scan JSON from a file or stdin.

    Exits with a clear message on parse errors or empty stdin.
    """
    try:
        if input_path:
            raw = Path(input_path).read_text(encoding='utf-8')
        else:
            raw = sys.stdin.read()
    except (OSError, KeyboardInterrupt) as exc:
        sys.exit(f'Error reading input: {exc}')

    if not raw.strip():
        sys.exit('Error: empty input (no JSON received on stdin or file).')

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        sys.exit(f'Error: invalid JSON — {exc}')

    # Schema version check — warn but don't fail so the script degrades
    # gracefully when the scan CLI evolves.
    schema_ver = data.get('version')
    if schema_ver is not None and schema_ver != _EXPECTED_SCHEMA_VERSION:
        print(
            f'Warning: scan JSON version is {schema_ver}, '
            f'expected {_EXPECTED_SCHEMA_VERSION}. '
            'Results may be inaccurate.',
            file=sys.stderr,
        )

    return data


def main(argv: list[str] | None = None) -> None:
    """Read scan JSON, triage, print report."""
    args = _parse_args(argv)

    data = _load_scan_json(args.input)

    diagnostics = data.get('diagnostics', [])
    if not diagnostics:
        print('No diagnostics to triage.')
        return

    # Merge default + user-supplied directory sets.
    forked_dirs = _DEFAULT_FORKED_DIRS | set(args.suppress_dirs)
    dev_dirs = _DEFAULT_DEV_DIRS | set(args.dev_dirs)

    buckets = triage(
        diagnostics, forked_dirs, dev_dirs,
        bulk_threshold=args.bulk_threshold,
    )

    # Output in the requested format.
    if args.format == 'json':
        print(format_json(buckets, len(diagnostics)))
    else:
        print(format_report(buckets, len(diagnostics)))


if __name__ == '__main__':
    main()

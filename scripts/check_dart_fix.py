"""Check for fixable dart analyzer issues.

Runs `dart fix --dry-run` and exits non-zero if any auto-fixable
issues are found.  Intended for CI or pre-push validation.

Usage:
    python scripts/check_dart_fix.py
"""

import re
import subprocess
import sys

# Multiple patterns because `dart fix --dry-run` output wording has
# changed across SDK versions (e.g. "fixes made" vs "fixes available");
# each pattern targets one known summary-line phrasing.
_FIX_PATTERNS = [
    re.compile(r'(\d+)\s+fix(?:es)?\s+(?:made|available)'),
    re.compile(r'(\d+)\s+fix(?:es)?\s+in\s+\d+\s+file'),
    re.compile(r'found\s+(\d+)\s+fix'),
]


def _parse_fix_count(output: str) -> int:
    for pattern in _FIX_PATTERNS:
        match = pattern.search(output)
        if match:
            return int(match.group(1))

    # Fallback: no summary line matched, so sum the per-file "- N fix"
    # breakdown lines instead of reporting a false zero.
    per_file = re.findall(r'-\s+(\d+)\s+fix', output)
    if per_file:
        return sum(int(n) for n in per_file)

    return 0


def main() -> int:
    try:
        result = subprocess.run(
            ['dart', 'fix', '--dry-run'],
            capture_output=True,
            text=True,
            timeout=300,
        )
    except FileNotFoundError:
        print('ERROR: dart not found on PATH.')
        return 2
    except subprocess.TimeoutExpired:
        print('ERROR: dart fix --dry-run timed out after 300s.')
        return 2

    # dart fix writes some summary lines to stderr depending on SDK version,
    # so both streams must be searched together.
    output = result.stdout + result.stderr
    fix_count = _parse_fix_count(output)

    if fix_count == 0:
        print('No fixable dart issues found.')
        return 0

    print(f'{fix_count} fixable dart issues found. Run `dart fix --apply` to resolve.')
    print(output)
    return 1


if __name__ == '__main__':
    sys.exit(main())

"""Check for fixable dart analyzer issues.

Runs `dart fix --dry-run` and exits non-zero if any auto-fixable
issues are found.  Intended for CI or pre-push validation.

Usage:
    python scripts/check_dart_fix.py
"""

import re
import subprocess
import sys


def main() -> int:
    result = subprocess.run(
        ['dart', 'fix', '--dry-run'],
        capture_output=True,
        text=True,
        timeout=300,
    )

    output = result.stdout + result.stderr

    match = re.search(r'(\d+)\s+fix(?:es)?\s+(?:made|available)', output)
    fix_count = int(match.group(1)) if match else 0

    if fix_count == 0:
        print('No fixable dart issues found.')
        return 0

    print(f'{fix_count} fixable dart issues found. Run `dart fix --apply` to resolve.')
    print(output)
    return 1


if __name__ == '__main__':
    sys.exit(main())

"""Check for recommended.yaml lint regressions.

Temporarily patches analysis_options.yaml to include
package:lints/recommended.yaml and removes the lib/** exclude, then runs
dart analyze on lib/. Verifies zero issues remain (all should be suppressed
with // ignore: comments). Restores the original file on exit, even on crash.

Uses dart analyze's exit code (non-zero = issues found) rather than parsing
its output format, which may change across SDK versions.

Usage:
    python scripts/check_recommended_yaml.py
"""

import re
import subprocess
import sys
from pathlib import Path

ANALYSIS_OPTIONS = Path('analysis_options.yaml')

INCLUDE_LINE = 'include: package:lints/recommended.yaml\n'


def _patch(original: str) -> str:
    """Insert recommended.yaml include and remove lib/** exclude."""
    lines = original.splitlines(keepends=True)

    patched: list[str] = []
    include_inserted = False
    for line in lines:
        stripped = line.strip()

        if not include_inserted and stripped and not stripped.startswith('#'):
            patched.append(INCLUDE_LINE)
            patched.append('\n')
            include_inserted = True

        if re.match(r'^\s*-\s*["\']?lib/\*\*["\']?\s*$', line):
            continue

        patched.append(line)

    if not include_inserted:
        patched.insert(0, INCLUDE_LINE)

    return ''.join(patched)


def main() -> int:
    if not ANALYSIS_OPTIONS.exists():
        print('ERROR: analysis_options.yaml not found.')
        return 1

    original_bytes = ANALYSIS_OPTIONS.read_bytes()
    original = original_bytes.decode('utf-8')

    if 'include:' in original:
        print(
            'ERROR: analysis_options.yaml already has an include: line. '
            'This script expects a standalone config without one.'
        )
        return 1

    try:
        patched = _patch(original)
        ANALYSIS_OPTIONS.write_text(patched, encoding='utf-8')

        try:
            result = subprocess.run(
                ['dart', 'analyze', 'lib/'],
                capture_output=True,
                text=True,
                timeout=300,
            )
        except FileNotFoundError:
            print('ERROR: dart not found on PATH.')
            return 2
        except subprocess.TimeoutExpired:
            print('ERROR: dart analyze timed out after 300s.')
            return 2

        if result.returncode == 0:
            print(
                'recommended.yaml: 0 issues. '
                'All lint rules satisfied or suppressed.'
            )
            return 0

        output = (result.stdout + result.stderr).strip()
        print(f'recommended.yaml: issues found (exit {result.returncode}):')
        if output:
            print(output)
        return 1

    finally:
        ANALYSIS_OPTIONS.write_bytes(original_bytes)


if __name__ == '__main__':
    sys.exit(main())

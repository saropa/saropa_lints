"""Check for recommended.yaml lint regressions.

Temporarily swaps analysis_options.yaml to use package:lints/recommended.yaml,
runs dart analyze on lib/, and verifies zero issues remain (all should be
suppressed with // ignore: comments). Restores the original file on exit.

Usage:
    python scripts/check_recommended_yaml.py
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ANALYSIS_OPTIONS = Path('analysis_options.yaml')


def main() -> int:
    if not ANALYSIS_OPTIONS.exists():
        print('analysis_options.yaml not found.')
        return 1

    original = ANALYSIS_OPTIONS.read_text(encoding='utf-8')

    with tempfile.NamedTemporaryFile(
        mode='w',
        suffix='.yaml',
        delete=False,
        encoding='utf-8',
    ) as backup:
        backup.write(original)
        backup_path = Path(backup.name)

    try:
        patched = original.replace(
            'include: analysis_options_saropa.yaml',
            'include: package:lints/recommended.yaml',
        )

        lines = patched.splitlines()
        filtered = []
        skip_next_indent = False
        for line in lines:
            stripped = line.lstrip()
            if stripped.startswith('- lib/**'):
                continue
            filtered.append(line)
        patched = '\n'.join(filtered) + '\n'

        ANALYSIS_OPTIONS.write_text(patched, encoding='utf-8')

        result = subprocess.run(
            ['dart', 'analyze', 'lib/'],
            capture_output=True,
            text=True,
            timeout=300,
        )

        output = result.stdout + result.stderr
        info_count = output.count(' - ')
        error_lines = [
            line for line in output.splitlines()
            if ' - ' in line and ('info' in line or 'warning' in line or 'error' in line)
        ]

        if not error_lines:
            print('recommended.yaml: 0 issues. All lint rules satisfied or suppressed.')
            return 0

        print(f'recommended.yaml: {len(error_lines)} issue(s) found:')
        for line in error_lines:
            print(f'  {line.strip()}')
        return 1

    finally:
        ANALYSIS_OPTIONS.write_text(original, encoding='utf-8')
        backup_path.unlink(missing_ok=True)


if __name__ == '__main__':
    sys.exit(main())

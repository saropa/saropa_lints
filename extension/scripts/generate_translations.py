#!/usr/bin/env python3
"""Generate translated extension locale files.

Sets up the environment and invokes generate_locales.py with the correct
Python interpreter. Eliminates shell-specific env var syntax differences
between PowerShell, cmd, and bash.

Requires: pip install deep-translator

Usage (from repo root):
    py -3 extension/scripts/generate_translations.py                    # all locales
    py -3 extension/scripts/generate_translations.py --locales bn,de    # specific locales
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    script_dir = Path(__file__).resolve().parent / "i18n"
    generate_script = script_dir / "generate_locales.py"
    if not generate_script.is_file():
        print(f"ERROR: {generate_script} not found.", file=sys.stderr)
        return 1

    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    env["SAROPA_I18N_MACHINE_TRANSLATE"] = "1"

    # Forward all args (e.g. --locales bn,de) to generate_locales.py.
    # Use the same Python that launched this script so deep-translator is found.
    cmd = [sys.executable, str(generate_script)] + sys.argv[1:]

    locales = _locales_from_args(sys.argv[1:])
    print(f"[generate_translations] python={sys.executable}", flush=True)
    print(f"[generate_translations] locales={locales}", flush=True)

    result = subprocess.run(cmd, env=env, cwd=str(script_dir))
    return result.returncode


def _locales_from_args(args: list[str]) -> str:
    """Extract --locales value for display, or 'all (default)' if absent."""
    for i, a in enumerate(args):
        if a == "--locales" and i + 1 < len(args):
            return args[i + 1]
        if a.startswith("--locales="):
            return a.split("=", 1)[1]
    return "all (default)"


if __name__ == "__main__":
    raise SystemExit(main())

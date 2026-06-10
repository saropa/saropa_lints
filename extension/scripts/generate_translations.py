#!/usr/bin/env python3
"""Generate translated extension locale files.

Sets up the environment and invokes generate_locales.py with the correct
Python interpreter. Eliminates shell-specific env var syntax differences
between PowerShell, cmd, and bash.

Translation engine: when the local Meta NLLB-200-3.3B model is available it is
used as the PRIMARY engine (much higher quality, especially for low-resource
languages), with Google Translate as the per-string fallback. Otherwise Google
Translate is used alone. The startup banner from generate_locales.py states
which engine is active.

Requires: pip install deep-translator (Google fallback). For NLLB quality, run
``py -3 extension/scripts/i18n/nllb_engine.py --setup`` once to download the
~7 GB model (reused automatically if it was already downloaded for the contacts
project). Set ``SAROPA_SKIP_NLLB=1`` to force Google-only.

Usage (from repo root):
    py -3 extension/scripts/generate_translations.py                    # all locales
    py -3 extension/scripts/generate_translations.py --locales bn,de    # specific locales
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

# Import the shared color helper from the i18n package directory. The path
# adjustment lets this wrapper colorize its own header lines consistently
# with the child generate_locales.py output.
sys.path.insert(0, str(Path(__file__).resolve().parent / "i18n"))
from term_color import c  # noqa: E402


def main() -> int:
    script_dir = Path(__file__).resolve().parent / "i18n"
    generate_script = script_dir / "generate_locales.py"
    if not generate_script.is_file():
        print(c("red", f"ERROR: {generate_script} not found."), file=sys.stderr)
        return 1

    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    env["SAROPA_I18N_MACHINE_TRANSLATE"] = "1"

    # Forward all args (e.g. --locales bn,de) to generate_locales.py.
    # Use the same Python that launched this script so deep-translator is found.
    cmd = [sys.executable, str(generate_script)] + sys.argv[1:]

    locales = _locales_from_args(sys.argv[1:])
    tag = c("magenta", "generate_translations")
    print(f"[{tag}] {c('gray', 'python=')}{sys.executable}", flush=True)
    print(f"[{tag}] {c('gray', 'locales=')}{c('cyan', locales)}", flush=True)

    # On Ctrl-C in PowerShell, both the child and this parent receive SIGINT.
    # The child handles it gracefully (saves cache, prints audit, exits 130).
    # We catch the parent's KeyboardInterrupt here so the user does not see a
    # Python traceback on top of the child's clean exit message.
    try:
        result = subprocess.run(cmd, env=env, cwd=str(script_dir))
        return result.returncode
    except KeyboardInterrupt:
        return 130


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

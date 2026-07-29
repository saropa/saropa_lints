#!/usr/bin/env python3
"""Generate translated extension locale files.

Sets up the environment and invokes generate_locales.py with the correct
Python interpreter. Eliminates shell-specific env var syntax differences
between PowerShell, cmd, and bash.

Translation engine: Qwen 3 via local Ollama (primary), Google Translate
(per-string fallback). See ``extension/scripts/i18n/qwen_engine.py``.

Requires: pip install deep-translator (Google fallback).
          Ollama installed from https://ollama.com/download (model pull is automatic).

Usage (from repo root):
    py -3 extension/scripts/generate_translations.py                    # all locales
    py -3 extension/scripts/generate_translations.py --locales bn,de    # specific locales
"""

from __future__ import annotations

import os
import signal
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

    cmd = [sys.executable, str(generate_script)] + sys.argv[1:]

    locales = _locales_from_args(sys.argv[1:])
    tag = c("magenta", "generate_translations")
    print(f"[{tag}] {c('gray', 'python=')}{sys.executable}", flush=True)
    print(f"[{tag}] {c('gray', 'locales=')}{c('cyan', locales)}", flush=True)

    signal.signal(signal.SIGINT, signal.SIG_IGN)
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

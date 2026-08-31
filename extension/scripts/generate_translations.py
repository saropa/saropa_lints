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
    if result.returncode != 0:
        return result.returncode

    # Commit generated translation files so they don't linger as dirty state.
    return _git_commit_translations(locales)


def _git_commit_translations(locales: str) -> int:
    """Stage and commit changed translation files.

    Only commits if there are actual changes to the locale/nls files.
    Returns 0 on success or when there's nothing to commit.
    """
    repo_root = Path(__file__).resolve().parent.parent.parent
    tag = c("magenta", "generate_translations")

    # Paths that the translation pipeline touches.
    paths_to_stage = [
        "extension/src/i18n/locales/",
        "extension/src/i18n/locale_coverage.json",
    ]

    # Stage only translation-related files. Bail on any staging failure
    # so a broken repo state doesn't silently skip the commit.
    for p in paths_to_stage:
        add_result = subprocess.run(
            ["git", "add", p],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
        )
        if add_result.returncode != 0:
            print(
                c("red", f"ERROR: git add {p} failed:\n{add_result.stderr}"),
                file=sys.stderr,
            )
            return add_result.returncode

    # Check whether anything was actually staged.
    diff = subprocess.run(
        ["git", "diff", "--cached", "--quiet"],
        cwd=str(repo_root),
        capture_output=True,
    )
    if diff.returncode == 0:
        # Nothing staged — translations unchanged.
        print(f"[{tag}] {c('gray', 'no translation changes to commit')}", flush=True)
        return 0

    # Build a descriptive commit message.
    if locales == "all (default)":
        msg = "chore: regenerate all translated locales"
    else:
        msg = f"chore: regenerate translations for {locales}"

    result = subprocess.run(
        ["git", "commit", "-m", msg],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(
            c("red", f"ERROR: git commit failed:\n{result.stderr}"),
            file=sys.stderr,
        )
        return result.returncode

    print(f"[{tag}] {c('green', 'committed:')} {msg}", flush=True)
    return 0


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

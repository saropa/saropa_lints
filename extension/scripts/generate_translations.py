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

Interpreter note: the shared NLLB runtime is built for the standard CPython ABI.
If ``py -3`` resolves to a free-threaded build (``python3.14t.exe``), this script
auto-relaunches under the standard ``python.exe`` beside it; numpy cannot load
otherwise. Pass a standard interpreter directly to skip the relaunch.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import sysconfig
from pathlib import Path

# Import the shared color helper from the i18n package directory. The path
# adjustment lets this wrapper colorize its own header lines consistently
# with the child generate_locales.py output.
sys.path.insert(0, str(Path(__file__).resolve().parent / "i18n"))
from term_color import c  # noqa: E402


def _reexec_under_standard_interpreter_if_free_threaded() -> None:
    """Re-launch under a standard CPython build when started free-threaded.

    The shared NLLB runtime (numpy + ctranslate2 in ``D:\\tools\\meta_nllb\\packages``,
    used by all four Saropa projects) is compiled for the standard CPython ABI
    (cp314). A free-threaded build (``python3.14t.exe``, ``Py_GIL_DISABLED=1``)
    uses the incompatible ``cp314t`` ABI and dies on ``import numpy`` with
    "_multiarray_umath ... incompatible". The ``py -3`` launcher this script's
    docs recommend now resolves to the free-threaded build on this machine, which
    is why only this package hit the failure while the siblings (invoked with a
    standard interpreter) did not. The standard build ships as ``python.exe`` in
    the same directory as the free-threaded one, so re-exec with that sibling;
    if it is absent, fail loudly with the exact command to run instead of letting
    the numpy ImportError surface deep inside the child process.
    """
    if not sysconfig.get_config_var("Py_GIL_DISABLED"):
        return

    standard = Path(sys.executable).with_name("python.exe")
    current = Path(sys.executable)
    # Guard against relaunching the same exe (would loop): require a distinct path.
    if standard.is_file() and standard.resolve() != current.resolve():
        print(
            c("yellow", f"[generate_translations] free-threaded interpreter "
              f"({current.name}) can't load the shared NLLB packages; "
              f"relaunching under {standard}"),
            flush=True,
        )
        # subprocess.run, NOT os.execv: on Windows os.execv does not replace the
        # process in place — it spawns a new process and the parent exits
        # immediately, so the shell prints its prompt back while the relaunched
        # child keeps reading/writing the same console. That interleaves output
        # and corrupts the interactive menu's stdin. Staying alive and blocking on
        # the child (and ignoring SIGINT so Ctrl-C is owned by the child chain,
        # matching main()) keeps exactly one process attached to the console.
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        result = subprocess.run([str(standard), *sys.argv])
        raise SystemExit(result.returncode)

    args = " ".join(sys.argv[1:])
    print(
        c("red", "ERROR: launched under a free-threaded Python "
          "(Py_GIL_DISABLED=1). The shared NLLB packages are built for the "
          "standard ABI and will fail at 'import numpy'. Re-run with a standard "
          f"interpreter, e.g.:\n    {standard} {Path(__file__).resolve()} {args}"),
        file=sys.stderr,
    )
    raise SystemExit(2)


def main() -> int:
    _reexec_under_standard_interpreter_if_free_threaded()
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

    # Let the CHILD own Ctrl-C. On Ctrl-C in PowerShell both processes get SIGINT;
    # the child stops gracefully (finishes the current string, flushes cache +
    # provenance, exits 130). The parent IGNORES SIGINT so it can't be torn down
    # mid-save and instead waits for the child's clean exit, then returns its code.
    # (The child re-installs its own handler at startup, so ignoring here doesn't
    # disable the child's graceful stop.)
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

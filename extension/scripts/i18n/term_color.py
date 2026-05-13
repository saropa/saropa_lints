"""ANSI color helper for terminal output.

Auto-detects TTY and enables virtual-terminal processing on Windows 10+ so
escape codes render in PowerShell, cmd, and Windows Terminal. Honors the
``NO_COLOR`` environment variable.
"""

from __future__ import annotations

import os
import sys

# Module-level cache: enable detection runs once on import.
_USE_COLOR: bool = False

_CODES: dict[str, str] = {
    "reset": "\033[0m",
    "bold": "\033[1m",
    "dim": "\033[2m",
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "blue": "\033[34m",
    "magenta": "\033[35m",
    "cyan": "\033[36m",
    "white": "\033[37m",
    "gray": "\033[90m",
}


def _try_enable_windows_vt() -> bool:
    """Enable ENABLE_VIRTUAL_TERMINAL_PROCESSING on the current stdout handle.

    Why: Windows consoles before this flag is set treat ANSI escapes as
    literal characters. Win10+ supports the flag; we set it on the inherited
    stdout handle so colored output renders in PowerShell and cmd.
    """
    if os.name != "nt":
        return True
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        # STD_OUTPUT_HANDLE = -11; ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004.
        handle = kernel32.GetStdHandle(-11)
        mode = ctypes.c_ulong()
        if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            return False
        return bool(
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)
        )
    except Exception:
        # Any failure (no ctypes, redirected handle, older Windows) -> no color.
        return False


def _detect_color() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if not sys.stdout.isatty():
        return False
    return _try_enable_windows_vt()


def enabled() -> bool:
    return _USE_COLOR


def c(name: str, text: str) -> str:
    """Wrap *text* in the ANSI sequence for *name* (e.g. ``"green"``)."""
    if not _USE_COLOR:
        return text
    code = _CODES.get(name)
    if code is None:
        return text
    return f"{code}{text}{_CODES['reset']}"


_USE_COLOR = _detect_color()

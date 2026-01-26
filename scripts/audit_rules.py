#!/usr/bin/env python3
"""
Audit implemented lint rules - backward-compatible entry point.

This script is a thin wrapper around ``scripts/modules/_audit.py``.
For the full audit logic, see that module.

Usage:
    python scripts/audit_rules.py [options]

Options:
    --dx-all          Show all DX issues (not just top 25)
    --no-dx           Skip DX message audit
    --compact         Compact output (skip file table)
    --silent          No output (exit code only)
    --warnings-only   Only show warnings and errors
    --verbose         Show all details (default)

Version:   3.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import sys
from pathlib import Path

# Allow running as `python scripts/audit_rules.py` from project root
_scripts_parent = str(Path(__file__).resolve().parent.parent)
if _scripts_parent not in sys.path:
    sys.path.insert(0, _scripts_parent)

from scripts.modules._utils import (
    OutputLevel,
    enable_ansi_support,
    print_header,
    set_output_level,
    show_saropa_logo,
)

SCRIPT_VERSION = "3.0"


def _parse_output_level() -> OutputLevel:
    """Determine output level from CLI args."""
    if "--silent" in sys.argv:
        return OutputLevel.SILENT
    if "--warnings-only" in sys.argv:
        return OutputLevel.WARNINGS_ONLY
    if "--verbose" in sys.argv:
        return OutputLevel.VERBOSE
    return OutputLevel.VERBOSE  # default for standalone audit


def main() -> int:
    """Main entry point for standalone audit."""
    enable_ansi_support()
    set_output_level(_parse_output_level())

    show_saropa_logo()
    print_header(f"SAROPA LINTS AUDIT v{SCRIPT_VERSION}")

    # Deferred import so module check in publish script can run first
    from scripts.modules._audit import run_full_audit

    result = run_full_audit(
        show_dx_all="--dx-all" in sys.argv,
        skip_dx="--no-dx" in sys.argv,
        compact="--compact" in sys.argv,
    )

    return 1 if result.has_blocking_issues else 0


if __name__ == "__main__":
    sys.exit(main())

"""Cross-reference every l10n() call in extension/src/ against en.json.

Exits 0 when every key resolves, 1 when orphans exist (missing from en.json
or defined but never referenced). Designed to run in CI alongside the
translation coverage gate.

Usage:
    python extension/scripts/check_l10n_keys.py
"""

from __future__ import annotations

import io
import json
import re
import sys
from pathlib import Path

# Force UTF-8 output on Windows where the console defaults to cp1252.
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# Repo-relative paths.
_REPO = Path(__file__).resolve().parents[2]
_SRC = _REPO / "extension" / "src"
_EN_JSON = _SRC / "i18n" / "locales" / "en.json"

# Matches l10n('dotted.key') with single or double quotes.
_L10N_RE = re.compile(r"""l10n\(\s*['"]([a-zA-Z0-9_.]+)['"]\s*[),]""")


def _flatten_keys(obj: dict, prefix: str = "") -> set[str]:
    """Flatten a nested dict into dotted key paths."""
    keys: set[str] = set()
    for k, v in obj.items():
        full = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            keys |= _flatten_keys(v, full)
        else:
            keys.add(full)
    return keys


def _collect_used_keys() -> dict[str, list[str]]:
    """Scan TypeScript sources for l10n() calls; return {key: [file:line, …]}."""
    used: dict[str, list[str]] = {}
    # Matches lines that are inside block comments or line comments.
    comment_re = re.compile(r"^\s*(?:\*|//)")
    for ts_file in sorted(_SRC.rglob("*.ts")):
        rel = ts_file.relative_to(_REPO)
        for lineno, line in enumerate(ts_file.read_text(encoding="utf-8").splitlines(), 1):
            # Skip comment lines — doc examples like l10n('domain.key') are
            # not real call sites.
            if comment_re.match(line):
                continue
            for m in _L10N_RE.finditer(line):
                key = m.group(1)
                used.setdefault(key, []).append(f"{rel}:{lineno}")
    return used


def main() -> int:
    # Load the canonical English catalog.
    catalog = json.loads(_EN_JSON.read_text(encoding="utf-8"))
    defined = _flatten_keys(catalog)
    used = _collect_used_keys()

    # Keys referenced in code but missing from en.json.
    missing = sorted(set(used) - defined)
    # Keys defined in en.json but never referenced in code.
    unused = sorted(defined - set(used))

    ok = True

    if missing:
        ok = False
        print(f"\n✗ {len(missing)} key(s) used in code but MISSING from en.json:\n")
        for key in missing:
            # Show the first call site for context.
            sites = used[key]
            print(f"  {key}")
            for s in sites[:3]:
                print(f"    ← {s}")
            if len(sites) > 3:
                print(f"    … and {len(sites) - 3} more")

    if unused:
        # Unused keys are a warning, not a hard failure — translations cost
        # money, so flag them, but don't block the build.
        print(f"\n⚠ {len(unused)} key(s) defined in en.json but never referenced in code:\n")
        for key in unused:
            print(f"  {key}")

    if ok:
        total = len(used)
        print(f"\n✓ All {total} l10n keys resolve against en.json.")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

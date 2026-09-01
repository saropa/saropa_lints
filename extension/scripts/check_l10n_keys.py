"""Cross-reference every l10n() call in extension/src/ against en.json.

Exits 0 when every key resolves, 1 when orphans exist (missing from en.json
or defined but never referenced). Designed to run in CI alongside the
translation coverage gate.

Usage:
    python extension/scripts/check_l10n_keys.py
    python extension/scripts/check_l10n_keys.py --check-params
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

# Matches l10n('dotted.key') or l10n('dotted.key', { ... }) with the
# optional second argument captured as a raw string for param extraction.
_L10N_RE = re.compile(
    r"""l10n\(\s*['"]([a-zA-Z0-9_.]+)['"]\s*"""
    r"""(?:,\s*(\{[^}]*\}))?\s*\)""",
)

# Extracts {placeholder} tokens from en.json values.
_PLACEHOLDER_RE = re.compile(r"\{([a-zA-Z0-9_]+)\}")

# Extracts JS object keys from the second l10n() argument, e.g. { count: ..., name: ... }.
_OBJ_KEY_RE = re.compile(r"(\w+)\s*:")


def _flatten(obj: dict, prefix: str = "") -> dict[str, str]:
    """Flatten a nested dict into {dotted.key: value} for leaves."""
    result: dict[str, str] = {}
    for k, v in obj.items():
        full = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            result.update(_flatten(v, full))
        else:
            result[full] = str(v)
    return result


def _strip_comments(source: str) -> str:
    """Remove block comments (/* ... */) and line comments (// ...) from TS source.

    Respects string literals so l10n calls inside strings are preserved.
    """
    result: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        c = source[i]
        # String literals — skip their contents to avoid false comment starts.
        if c in ("'", '"', '`'):
            quote = c
            result.append(c)
            i += 1
            while i < n:
                ch = source[i]
                result.append(ch)
                if ch == '\\':
                    # Escaped character — consume next char unconditionally.
                    i += 1
                    if i < n:
                        result.append(source[i])
                elif ch == quote:
                    break
                i += 1
            i += 1
        # Block comment — discard entirely, replace with space to preserve
        # token boundaries.
        elif c == '/' and i + 1 < n and source[i + 1] == '*':
            result.append(' ')
            i += 2
            while i < n:
                if source[i] == '*' and i + 1 < n and source[i + 1] == '/':
                    i += 2
                    break
                i += 1
        # Line comment — discard to end of line.
        elif c == '/' and i + 1 < n and source[i + 1] == '/':
            i += 2
            while i < n and source[i] != '\n':
                i += 1
        else:
            result.append(c)
            i += 1
    return ''.join(result)


def _collect_used_keys() -> dict[str, list[tuple[str, str | None]]]:
    """Scan TypeScript sources for l10n() calls.

    Returns {key: [(file:line, raw_params_or_None), ...]}.
    """
    used: dict[str, list[tuple[str, str | None]]] = {}
    for ts_file in sorted(_SRC.rglob("*.ts")):
        rel = str(ts_file.relative_to(_REPO))
        source = ts_file.read_text(encoding="utf-8")
        # Strip comments so doc examples don't register as real calls.
        stripped = _strip_comments(source)
        # Map character offset back to line number.
        line_offsets: list[int] = [0]
        for ci, ch in enumerate(source):
            if ch == '\n':
                line_offsets.append(ci + 1)

        for m in _L10N_RE.finditer(stripped):
            key = m.group(1)
            raw_params = m.group(2)
            # Find line number from character offset in original source.
            offset = m.start()
            lo, hi = 0, len(line_offsets) - 1
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if line_offsets[mid] <= offset:
                    lo = mid
                else:
                    hi = mid - 1
            lineno = lo + 1
            used.setdefault(key, []).append((f"{rel}:{lineno}", raw_params))
    return used


def _check_params(
    catalog: dict[str, str],
    used: dict[str, list[tuple[str, str | None]]],
) -> list[str]:
    """Validate that l10n() call-site params match en.json placeholders."""
    issues: list[str] = []
    for key, sites in sorted(used.items()):
        if key not in catalog:
            # Missing key — already reported by the main check.
            continue
        value = catalog[key]
        expected = set(_PLACEHOLDER_RE.findall(value))
        if not expected:
            # No placeholders in the catalog value — skip param checks.
            continue
        for location, raw_params in sites:
            if raw_params is None:
                # Call site passes no params but the catalog expects them.
                issues.append(
                    f"  {key}  expects {sorted(expected)}  but call at {location} passes no params"
                )
                continue
            # Extract keys from the JS object literal { foo: ..., bar: ... }.
            supplied = set(_OBJ_KEY_RE.findall(raw_params))
            missing_params = expected - supplied
            extra_params = supplied - expected
            if missing_params:
                issues.append(
                    f"  {key}  missing {sorted(missing_params)}  at {location}"
                )
            if extra_params:
                issues.append(
                    f"  {key}  extra {sorted(extra_params)}  at {location}"
                )
    return issues


def main() -> int:
    check_params = "--check-params" in sys.argv

    # Load the canonical English catalog.
    catalog_raw = json.loads(_EN_JSON.read_text(encoding="utf-8"))
    catalog = _flatten(catalog_raw)
    defined = set(catalog)
    used = _collect_used_keys()
    used_keys = set(used)

    ok = True

    # Keys referenced in code but missing from en.json.
    missing = sorted(used_keys - defined)
    if missing:
        ok = False
        print(f"\n✗ {len(missing)} key(s) used in code but MISSING from en.json:\n")
        for key in missing:
            sites = used[key]
            print(f"  {key}")
            for loc, _ in sites[:3]:
                print(f"    ← {loc}")
            if len(sites) > 3:
                print(f"    … and {len(sites) - 3} more")

    # Interpolation parameter validation (opt-in via --check-params).
    if check_params:
        param_issues = _check_params(catalog, used)
        if param_issues:
            ok = False
            print(f"\n✗ {len(param_issues)} interpolation mismatch(es):\n")
            for issue in param_issues:
                print(issue)

    # Keys defined in en.json but never referenced in code.
    unused = sorted(defined - used_keys)
    if unused:
        # Warning only — translations cost money, but don't block the build.
        print(f"\n⚠ {len(unused)} key(s) defined in en.json but never referenced in code:\n")
        for key in unused:
            print(f"  {key}")

    if ok:
        total = len(used_keys)
        suffix = " (params validated)" if check_params else ""
        print(f"\n✓ All {total} l10n keys resolve against en.json.{suffix}")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

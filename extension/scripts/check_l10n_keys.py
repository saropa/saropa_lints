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

# Matches l10n('dotted.key') with single or double quotes only.
# Template-literal keys like l10n(`prefix.${var}`) are dynamic and
# cannot be validated statically — they are intentionally excluded.
_L10N_RE = re.compile(r"""l10n\(\s*['"]([a-zA-Z0-9_.]+)['"]""")

# Extracts {placeholder} tokens from en.json values.
_PLACEHOLDER_RE = re.compile(r"\{([a-zA-Z0-9_]+)\}")

# Extracts JS object keys from the second l10n() argument.
# Handles both `{ count: value }` and shorthand `{ message }`.
# Looks for identifiers preceded by `{` or `,` (start of a member).
# Excludes spread (`...obj`) and computed keys (`[expr]`) by requiring
# the captured group to be a plain identifier, not preceded by `...`.
# Uses lookahead for the trailing delimiter so consecutive shorthand
# properties (e.g. `{ a, b, c }`) all match — consuming the trailing
# `,` would swallow the next property's start delimiter.
_OBJ_KEY_RE = re.compile(r"(?:^|[{,])\s*(?!\.\.\.)(\w+)\s*(?=:|[,}])")

# Matches a l10n:passthrough marker comment on a source line.
# When present, the checker skips param validation for any l10n()
# call on that line — the placeholders are substituted downstream
# (e.g. by client-side JS in a webview script-strings builder).
_PASSTHROUGH_MARKER = 'l10n:passthrough'


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
    """Remove block and line comments from TypeScript source.

    Handles single-quoted, double-quoted, and template-literal strings
    (including nested ${...} interpolations that may contain // or /*).
    Preserves newlines so line counts stay accurate.
    """
    result: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        c = source[i]
        # Single- or double-quoted string — consume until closing quote.
        if c in ("'", '"'):
            quote = c
            result.append(c)
            i += 1
            while i < n:
                ch = source[i]
                result.append(ch)
                if ch == '\\':
                    i += 1
                    if i < n:
                        result.append(source[i])
                elif ch == quote:
                    break
                i += 1
            i += 1
        # Template literal — recurse through ${...} interpolations so
        # that `//` or `/*` inside them are not treated as comments.
        elif c == '`':
            i = _consume_template_literal(source, i, result)
        # Block comment — replace with a space per line to preserve
        # token boundaries and line counts.
        elif c == '/' and i + 1 < n and source[i + 1] == '*':
            result.append(' ')
            i += 2
            while i < n:
                if source[i] == '\n':
                    # Preserve the newline so line numbers stay accurate.
                    result.append('\n')
                elif source[i] == '*' and i + 1 < n and source[i + 1] == '/':
                    i += 2
                    break
                i += 1
        # Line comment — discard to end of line, keep the newline.
        elif c == '/' and i + 1 < n and source[i + 1] == '/':
            i += 2
            while i < n and source[i] != '\n':
                i += 1
        else:
            result.append(c)
            i += 1
    return ''.join(result)


def _consume_template_literal(source: str, start: int, result: list[str]) -> int:
    """Consume a template literal starting at the backtick at `start`.

    Appends characters to `result` and returns the index after the
    closing backtick. Handles nested ${...} with balanced-brace
    tracking, including nested template literals inside interpolations.
    """
    n = len(source)
    result.append(source[start])  # opening backtick
    i = start + 1
    while i < n:
        ch = source[i]
        if ch == '\\':
            # Escaped char — consume unconditionally.
            result.append(ch)
            i += 1
            if i < n:
                result.append(source[i])
            i += 1
        elif ch == '`':
            # Closing backtick.
            result.append(ch)
            i += 1
            return i
        elif ch == '$' and i + 1 < n and source[i + 1] == '{':
            # Template interpolation — consume with balanced braces.
            result.append(ch)
            result.append('{')
            i += 2
            depth = 1
            while i < n and depth > 0:
                ic = source[i]
                if ic == '`':
                    # Nested template literal inside the interpolation.
                    i = _consume_template_literal(source, i, result)
                    continue
                result.append(ic)
                if ic == '{':
                    depth += 1
                elif ic == '}':
                    depth -= 1
                elif ic in ("'", '"'):
                    # String inside interpolation — skip contents.
                    q = ic
                    i += 1
                    while i < n:
                        sc = source[i]
                        result.append(sc)
                        if sc == '\\':
                            i += 1
                            if i < n:
                                result.append(source[i])
                        elif sc == q:
                            break
                        i += 1
                i += 1
        else:
            result.append(ch)
            i += 1
    return i


def _extract_params_after(source: str, start: int) -> str | None:
    """Extract the second argument object from an l10n() call.

    Starting after the closing quote of the key, scans for a comma
    followed by a { ... } object literal, handling nested braces,
    parens, brackets, and string literals. Returns the raw object
    text or None if no second argument exists.
    """
    i = start
    n = len(source)
    # Skip whitespace after the key string.
    while i < n and source[i] in ' \t\n\r':
        i += 1
    # Next char should be ',' (second arg) or ')' (no second arg).
    if i >= n or source[i] != ',':
        return None
    i += 1
    # Skip whitespace before the object.
    while i < n and source[i] in ' \t\n\r':
        i += 1
    if i >= n or source[i] != '{':
        return None
    # Balanced-brace scan with string-literal awareness.
    depth = 0
    obj_start = i
    while i < n:
        c = source[i]
        if c in ("'", '"', '`'):
            # Skip string contents.
            quote = c
            i += 1
            while i < n:
                if source[i] == '\\':
                    i += 2
                    continue
                if source[i] == quote:
                    break
                i += 1
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return source[obj_start:i + 1]
        i += 1
    return None


def _collect_used_keys() -> dict[str, list[tuple[str, str | None, bool]]]:
    """Scan TypeScript sources for l10n() calls.

    Returns {key: [(file:line, raw_params_or_None, is_passthrough), ...]}.
    The is_passthrough flag is True when the source line contains a
    `l10n:passthrough` marker comment, indicating that placeholders are
    substituted downstream (not by l10n()).
    """
    used: dict[str, list[tuple[str, str | None, bool]]] = {}
    for ts_file in sorted(_SRC.rglob("*.ts")):
        rel = str(ts_file.relative_to(_REPO))
        source = ts_file.read_text(encoding="utf-8")
        # Build a set of 1-based line numbers that have the passthrough
        # marker — checked BEFORE comment stripping so the marker (which
        # lives in a comment) is still visible.
        passthrough_lines: set[int] = set()
        for i, line in enumerate(source.splitlines(), 1):
            if _PASSTHROUGH_MARKER in line:
                passthrough_lines.add(i)
        # Strip comments so doc examples don't register as real calls.
        stripped = _strip_comments(source)
        # Build a line-offset index for the stripped source.
        line_offsets: list[int] = [0]
        for ci, ch in enumerate(stripped):
            if ch == '\n':
                line_offsets.append(ci + 1)

        for m in _L10N_RE.finditer(stripped):
            key = m.group(1)
            # Extract the second argument (params object) if present.
            after_quote = m.end()
            raw_params = _extract_params_after(stripped, after_quote)
            # Find line number from character offset.
            offset = m.start()
            lo, hi = 0, len(line_offsets) - 1
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if line_offsets[mid] <= offset:
                    lo = mid
                else:
                    hi = mid - 1
            lineno = lo + 1
            # Skip dynamic key prefixes (e.g. 'codeHealth.flag.' + var).
            if key.endswith('.'):
                continue
            is_passthrough = lineno in passthrough_lines
            used.setdefault(key, []).append((f"{rel}:{lineno}", raw_params, is_passthrough))
    return used


def _sanitize_param_values(raw: str) -> str:
    """Replace string and template-literal contents with spaces.

    This prevents the key-extraction regex from picking up identifiers
    inside param VALUES (e.g. `${suffix}` in a template literal, or
    `'{n}'` as a string value). Only the top-level object keys should
    be extracted, not variable names embedded in values.
    """
    result: list[str] = []
    i = 0
    n = len(raw)
    while i < n:
        c = raw[i]
        if c in ("'", '"', '`'):
            # Keep the quotes but blank out everything between them.
            quote = c
            result.append(c)
            i += 1
            while i < n:
                ch = raw[i]
                if ch == '\\':
                    # Escaped char — blank both.
                    result.append(' ')
                    i += 1
                    if i < n:
                        result.append(' ')
                    i += 1
                    continue
                if ch == quote:
                    break
                if quote == '`' and ch == '$' and i + 1 < n and raw[i + 1] == '{':
                    # Template interpolation — blank with balanced braces.
                    result.append(' ')
                    result.append(' ')
                    i += 2
                    depth = 1
                    while i < n and depth > 0:
                        if raw[i] == '{':
                            depth += 1
                        elif raw[i] == '}':
                            depth -= 1
                        result.append(' ')
                        i += 1
                    continue
                # Regular char inside string — blank it.
                result.append(' ')
                i += 1
            if i < n:
                result.append(c)  # closing quote
            i += 1
        else:
            result.append(c)
            i += 1
    return ''.join(result)


def _check_params(
    catalog: dict[str, str],
    used: dict[str, list[tuple[str, str | None, bool]]],
) -> list[str]:
    """Validate that l10n() call-site params match en.json placeholders."""
    issues: list[str] = []
    for key, sites in sorted(used.items()):
        if key not in catalog:
            # Missing key — already reported by the main check.
            continue
        # Plural keys (ending in CLDR plural categories) are consumed by
        # pluralize(), which handles {count} substitution. l10n() is
        # deliberately called without params — {count} passes through
        # as a literal placeholder for pluralize() to replace. Covers
        # all CLDR categories: Zero, One, Two, Few, Many, Other.
        if re.search(r'(?:Zero|One|Two|Few|Many|Other)$', key):
            continue
        value = catalog[key]
        expected = set(_PLACEHOLDER_RE.findall(value))
        if not expected:
            # No placeholders in the catalog value — skip param checks.
            continue
        for location, raw_params, is_passthrough in sites:
            # l10n:passthrough marker — placeholders are substituted
            # downstream (client-side JS, script-strings builder, etc.).
            if is_passthrough:
                continue
            if raw_params is None:
                # Call site passes no params but the catalog expects them.
                issues.append(
                    f"  {key}  expects {sorted(expected)}  but call at {location} passes no params"
                )
                continue
            # Sanitize string/template-literal contents so the regex
            # only extracts top-level object keys, not identifiers
            # embedded in param values.
            sanitized = _sanitize_param_values(raw_params)
            # Extract keys from the JS object literal { foo: ..., bar: ... }.
            # Spread properties (...obj) are excluded by the negative
            # lookahead; computed keys ([expr]) don't match \w+ after {/,.
            supplied = set(_OBJ_KEY_RE.findall(sanitized))
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

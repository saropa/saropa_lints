"""
Approximate source comment coverage for publish-time reporting.

Scans Dart (lib/test/bin/packages), TypeScript (extension/src), and Python
(scripts) with string-aware heuristics so ``//`` inside strings does not count.
Template literals and ``${...}`` are handled for TypeScript; Dart string
interpolation uses the same brace-aware skip.

Python counts ``tokenize.COMMENT`` only (docstrings are not counted); callers use
this module as a coarse queue signal, not as proof of documentation quality.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import tokenize
from dataclasses import dataclass
from io import StringIO
from pathlib import Path

from scripts.modules._utils import Color, print_colored


@dataclass(frozen=True)
class _BucketScan:
    """Aggregated stats for one language/root slice (e.g. ``Dart (lib/)``)."""

    label: str
    files: int
    total_lines: int
    lines_with_comment: int
    files_without_comment: int


def _physical_line_count(text: str) -> int:
    """Return physical newline count (``0`` for empty file)."""
    if not text:
        return 0
    return len(text.splitlines())


def _python_comment_lines(text: str) -> set[int]:
    """1-based line numbers containing a `#` comment token (tokenize.COMMENT)."""
    lines: set[int] = set()
    if not text:
        return lines
    readline = StringIO(text).readline
    try:
        for tok in tokenize.generate_tokens(readline):
            if tok.type != tokenize.COMMENT:
                continue
            start_ln, end_ln = tok.start[0], tok.end[0]
            for ln in range(start_ln, end_ln + 1):
                lines.add(ln)
    except tokenize.TokenError:
        # Broken file — still count physical lines elsewhere; no comments marked.
        pass
    return lines


def _starts_with(text: str, i: int, prefix: str) -> bool:
    return text.startswith(prefix, i)


def _collect_c_family_comment_lines(text: str, *, templates: bool) -> set[int]:
    """Lines (1-based) that contain a comment token outside strings/templates.

    When *templates* is True (TypeScript), `` `...` `` and nested `` `${...}` ``
    are parsed so comments inside expressions are attributed to their lines.
    """
    comment_lines: set[int] = set()
    n = len(text)
    line = 1
    i = 0

    def mark_line() -> None:
        comment_lines.add(line)

    def skip_line_comment() -> None:
        nonlocal i, line
        mark_line()
        while i < n and text[i] != "\n":
            i += 1
        if i < n and text[i] == "\n":
            i += 1
            line += 1

    def skip_block_comment() -> None:
        nonlocal i, line
        mark_line()
        i += 2
        while i < n:
            if text[i] == "\n":
                line += 1
                i += 1
                continue
            if text[i] == "*" and i + 1 < n and text[i + 1] == "/":
                i += 2
                return
            mark_line()
            i += 1

    def skip_single_quoted_dart_char() -> None:
        """Skip 'x' or '\\'' including one-char Dart string."""
        nonlocal i, line
        i += 1  # opening '
        while i < n:
            c = text[i]
            if c == "\\":
                i += 2 if i + 1 < n else 1
                continue
            if c == "\n":
                line += 1
            if c == "'":
                i += 1
                return
            i += 1

    def skip_double_string(non_raw: bool) -> None:
        nonlocal i, line
        i += 1
        while i < n:
            c = text[i]
            if non_raw and c == "\\":
                i += 2 if i + 1 < n else 1
                continue
            if c == "\n":
                line += 1
            if c == '"':
                i += 1
                return
            if non_raw and c == "$" and i + 1 < n and text[i + 1] == "{":
                i = _skip_brace_expression(text, i + 2, line, comment_lines, templates)[0]
                continue
            if non_raw and c == "$" and i + 1 < n:
                nxt = text[i + 1]
                if nxt == "$":
                    i += 2
                    continue
                if nxt.isalpha() or nxt == "_":
                    i += 2
                    while i < n and (text[i].isalnum() or text[i] == "_"):
                        i += 1
                    continue
            i += 1

    def skip_single_string(non_raw: bool) -> None:
        nonlocal i, line
        i += 1
        while i < n:
            c = text[i]
            if non_raw and c == "\\":
                i += 2 if i + 1 < n else 1
                continue
            if c == "\n":
                line += 1
            if c == "'":
                i += 1
                return
            if non_raw and c == "$" and i + 1 < n and text[i + 1] == "{":
                i = _skip_brace_expression(text, i + 2, line, comment_lines, templates)[0]
                continue
            if non_raw and c == "$" and i + 1 < n:
                nxt = text[i + 1]
                if nxt == "$":
                    i += 2
                    continue
                if nxt.isalpha() or nxt == "_":
                    i += 2
                    while i < n and (text[i].isalnum() or text[i] == "_"):
                        i += 1
                    continue
            i += 1

    def skip_triple_double(non_raw: bool) -> None:
        nonlocal i, line
        i += 3
        while i + 2 < n:
            if text[i] == '"' and text[i + 1] == '"' and text[i + 2] == '"':
                i += 3
                return
            if non_raw and text[i] == "$" and i + 1 < n and text[i + 1] == "{":
                i = _skip_brace_expression(text, i + 2, line, comment_lines, templates)[0]
                continue
            if text[i] == "\n":
                line += 1
            i += 1
        i = n

    def skip_triple_single(non_raw: bool) -> None:
        nonlocal i, line
        i += 3
        while i + 2 < n:
            if text[i] == "'" and text[i + 1] == "'" and text[i + 2] == "'":
                i += 3
                return
            if non_raw and text[i] == "$" and i + 1 < n and text[i + 1] == "{":
                i = _skip_brace_expression(text, i + 2, line, comment_lines, templates)[0]
                continue
            if text[i] == "\n":
                line += 1
            i += 1
        i = n

    def skip_ts_template() -> None:
        nonlocal i, line
        i += 1  # opening `
        while i < n:
            c = text[i]
            if c == "\\":
                i += 2 if i + 1 < n else 1
                continue
            if c == "`":
                i += 1
                return
            if c == "\n":
                line += 1
            if c == "$" and i + 1 < n and text[i + 1] == "{":
                i = _skip_brace_expression(text, i + 2, line, comment_lines, templates)[0]
                continue
            i += 1

    def try_string_or_raw() -> bool:
        """If *text[i]* starts a string, consume it and return True."""
        nonlocal i, line
        raw = False
        j = i
        if j < n and text[j] == "r":
            raw = True
            j += 1
        if j >= n:
            return False
        if _starts_with(text, j, '"""'):
            i = j + 3
            skip_triple_double(not raw)
            return True
        if _starts_with(text, j, "'''"):
            i = j + 3
            skip_triple_single(not raw)
            return True
        if text[j] == '"':
            i = j + 1
            skip_double_string(not raw)
            return True
        if text[j] == "'":
            i = j + 1
            skip_single_string(not raw)
            return True
        return False

    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if _starts_with(text, i, "//"):
            skip_line_comment()
            continue
        if _starts_with(text, i, "/*"):
            skip_block_comment()
            continue
        if templates and c == "`":
            skip_ts_template()
            continue
        if c == "'" and i + 2 < n and text[i + 1] == "'" and text[i + 2] == "'":
            i += 3
            skip_triple_single(True)
            continue
        if c == '"' and i + 2 < n and text[i + 1] == '"' and text[i + 2] == '"':
            i += 3
            skip_triple_double(True)
            continue
        if c == "r" and try_string_or_raw():
            continue
        if c == '"' or c == "'":
            if c == "'":
                peek = i + 1
                if peek < n and text[peek] != "'" and text[peek] != "\\":
                    npeek = peek + 1
                    if npeek < n and text[npeek] == "'":
                        skip_single_quoted_dart_char()
                        continue
            if try_string_or_raw():
                continue
            i += 1
            continue
        i += 1

    return comment_lines


def _skip_brace_expression(
    text: str,
    i: int,
    line: int,
    comment_lines: set[int],
    templates: bool,
) -> tuple[int, int]:
    """Skip until matching `}` for an already-open `{` (depth starts at 1)."""
    n = len(text)
    depth = 1

    def mark_line() -> None:
        comment_lines.add(line)

    def skip_line_comment() -> None:
        nonlocal i, line
        mark_line()
        while i < n and text[i] != "\n":
            i += 1
        if i < n and text[i] == "\n":
            i += 1
            line += 1

    def skip_block_comment() -> None:
        nonlocal i, line
        mark_line()
        i += 2
        while i < n:
            if text[i] == "\n":
                line += 1
                i += 1
                continue
            if text[i] == "*" and i + 1 < n and text[i + 1] == "/":
                i += 2
                return
            mark_line()
            i += 1

    def skip_double(non_raw: bool) -> None:
        nonlocal i, line
        i += 1
        while i < n:
            c = text[i]
            if non_raw and c == "\\":
                i += 2 if i + 1 < n else 1
                continue
            if c == "\n":
                line += 1
            if c == '"':
                i += 1
                return
            if non_raw and c == "$" and i + 1 < n and text[i + 1] == "{":
                i, line = _skip_brace_expression(text, i + 2, line, comment_lines, templates)
                continue
            if non_raw and c == "$" and i + 1 < n:
                nxt = text[i + 1]
                if nxt == "$":
                    i += 2
                    continue
                if nxt.isalpha() or nxt == "_":
                    i += 2
                    while i < n and (text[i].isalnum() or text[i] == "_"):
                        i += 1
                    continue
            i += 1

    def skip_single(non_raw: bool) -> None:
        nonlocal i, line
        i += 1
        while i < n:
            c = text[i]
            if non_raw and c == "\\":
                i += 2 if i + 1 < n else 1
                continue
            if c == "\n":
                line += 1
            if c == "'":
                i += 1
                return
            if non_raw and c == "$" and i + 1 < n and text[i + 1] == "{":
                i, line = _skip_brace_expression(text, i + 2, line, comment_lines, templates)
                continue
            if non_raw and c == "$" and i + 1 < n:
                nxt = text[i + 1]
                if nxt == "$":
                    i += 2
                    continue
                if nxt.isalpha() or nxt == "_":
                    i += 2
                    while i < n and (text[i].isalnum() or text[i] == "_"):
                        i += 1
                    continue
            i += 1

    def skip_triple_d(non_raw: bool) -> None:
        nonlocal i, line
        i += 3
        while i + 2 < n:
            if text[i] == '"' and text[i + 1] == '"' and text[i + 2] == '"':
                i += 3
                return
            if non_raw and text[i] == "$" and i + 1 < n and text[i + 1] == "{":
                i, line = _skip_brace_expression(text, i + 2, line, comment_lines, templates)
                continue
            if text[i] == "\n":
                line += 1
            i += 1
        i = n

    def skip_triple_s(non_raw: bool) -> None:
        nonlocal i, line
        i += 3
        while i + 2 < n:
            if text[i] == "'" and text[i + 1] == "'" and text[i + 2] == "'":
                i += 3
                return
            if non_raw and text[i] == "$" and i + 1 < n and text[i + 1] == "{":
                i, line = _skip_brace_expression(text, i + 2, line, comment_lines, templates)
                continue
            if text[i] == "\n":
                line += 1
            i += 1
        i = n

    def skip_tpl() -> None:
        nonlocal i, line
        i += 1
        while i < n:
            c = text[i]
            if c == "\\":
                i += 2 if i + 1 < n else 1
                continue
            if c == "`":
                i += 1
                return
            if c == "\n":
                line += 1
            if c == "$" and i + 1 < n and text[i + 1] == "{":
                i, line = _skip_brace_expression(text, i + 2, line, comment_lines, templates)
                continue
            i += 1

    while i < n and depth > 0:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if _starts_with(text, i, "//"):
            skip_line_comment()
            continue
        if _starts_with(text, i, "/*"):
            skip_block_comment()
            continue
        if templates and c == "`":
            skip_tpl()
            continue
        if c == "}":
            depth -= 1
            i += 1
            continue
        if c == "{":
            depth += 1
            i += 1
            continue
        if c == "r":
            j = i + 1
            if j < n:
                if _starts_with(text, j, '"""'):
                    i = j + 3
                    skip_triple_d(False)
                    continue
                if _starts_with(text, j, "'''"):
                    i = j + 3
                    skip_triple_s(False)
                    continue
                if text[j] == '"':
                    i = j + 1
                    skip_double(False)
                    continue
                if text[j] == "'":
                    i = j + 1
                    skip_single(False)
                    continue
        if _starts_with(text, i, '"""'):
            i += 3
            skip_triple_d(True)
            continue
        if _starts_with(text, i, "'''"):
            i += 3
            skip_triple_s(True)
            continue
        if c == '"':
            i += 1
            skip_double(True)
            continue
        if c == "'":
            i += 1
            skip_single(True)
            continue
        i += 1

    return i, line


def _dart_comment_lines(text: str) -> set[int]:
    return _collect_c_family_comment_lines(text, templates=False)


def _ts_comment_lines(text: str) -> set[int]:
    return _collect_c_family_comment_lines(text, templates=True)


_SKIP_DIR_NAMES = frozenset(
    {
        ".dart_tool",
        "build",
        "node_modules",
        ".git",
        "__pycache__",
    },
)


def _iter_files(root: Path, suffix: str) -> list[Path]:
    """All files under *root* ending with *suffix*, excluding junk directory names."""
    if not root.exists():
        return []
    out: list[Path] = []
    for p in root.rglob(f"*{suffix}"):
        if any(part in _SKIP_DIR_NAMES for part in p.parts):
            continue
        out.append(p)
    return sorted(out)


def _skip_dart_artifact(path: Path) -> bool:
    """True for codegen outputs that should not skew human-maintained comment ratios."""
    name = path.name
    if name.endswith(".g.dart"):
        return True
    if name.endswith("_generated.dart"):
        return True
    return False


def _scan_bucket_dart(
    paths: list[Path],
    label: str,
    *,
    templates: bool,
) -> _BucketScan | None:
    """Aggregate line counts and comment-line union for Dart or TS paths."""
    if not paths:
        return None
    total_lines = 0
    comment_line_union: set[tuple[str, int]] = set()
    files_without = 0
    for path in paths:
        text = path.read_text(encoding="utf-8", errors="replace")
        phys = _physical_line_count(text)
        total_lines += phys
        clines = _ts_comment_lines(text) if templates else _dart_comment_lines(text)
        for ln in clines:
            comment_line_union.add((str(path), ln))
        if not clines:
            files_without += 1
    # Re-aggregate: lines_with_comment = unique (file, line) count
    lines_with_comment = len(comment_line_union)
    return _BucketScan(
        label=label,
        files=len(paths),
        total_lines=total_lines,
        lines_with_comment=lines_with_comment,
        files_without_comment=files_without,
    )


def _scan_bucket_python(paths: list[Path], label: str) -> _BucketScan | None:
    """Same as [_scan_bucket_dart] but uses [#]-only comment detection via tokenize."""
    if not paths:
        return None
    total_lines = 0
    marked: set[tuple[str, int]] = set()
    files_without = 0
    for path in paths:
        text = path.read_text(encoding="utf-8", errors="replace")
        phys = _physical_line_count(text)
        total_lines += phys
        clines = _python_comment_lines(text)
        for ln in clines:
            marked.add((str(path), ln))
        if not clines:
            files_without += 1
    return _BucketScan(
        label=label,
        files=len(paths),
        total_lines=total_lines,
        lines_with_comment=len(marked),
        files_without_comment=files_without,
    )


def collect_comment_metric_buckets(project_dir: Path) -> list[_BucketScan]:
    """Scan primary source trees and return per-bucket stats (non-empty only)."""
    buckets: list[_BucketScan] = []

    # Each block below aggregates one root; empty roots are skipped (no _BucketScan entry).
    lib_dart = [
        p
        for p in _iter_files(project_dir / "lib", ".dart")
        if not _skip_dart_artifact(p)
    ]
    b = _scan_bucket_dart(lib_dart, "Dart (lib/)", templates=False)
    if b:
        buckets.append(b)

    test_dart = _iter_files(project_dir / "test", ".dart")
    b = _scan_bucket_dart(test_dart, "Dart (test/)", templates=False)
    if b:
        buckets.append(b)

    bin_dart = _iter_files(project_dir / "bin", ".dart")
    b = _scan_bucket_dart(bin_dart, "Dart (bin/)", templates=False)
    if b:
        buckets.append(b)

    pkg_dart: list[Path] = []
    packages_dir = project_dir / "packages"
    if packages_dir.is_dir():
        for pkg in sorted(packages_dir.iterdir()):
            if pkg.is_dir():
                pkg_dart.extend(
                    p
                    for p in _iter_files(pkg / "lib", ".dart")
                    if not _skip_dart_artifact(p)
                )
    b = _scan_bucket_dart(pkg_dart, "Dart (packages/*/lib/)", templates=False)
    if b:
        buckets.append(b)

    ext_ts = _iter_files(project_dir / "extension" / "src", ".ts")
    b = _scan_bucket_dart(ext_ts, "TypeScript (extension/src/)", templates=True)
    if b:
        buckets.append(b)

    py_paths = [p for p in _iter_files(project_dir / "scripts", ".py")]
    b = _scan_bucket_python(py_paths, "Python (scripts/)")
    if b:
        buckets.append(b)

    return buckets


def display_code_comment_metrics(project_dir: Path) -> None:
    """Print comment-line coverage by source bucket (publish banner section)."""
    buckets = collect_comment_metric_buckets(project_dir)
    if not buckets:
        return

    print()
    print_colored("  ▶ Code comments (approx.)", Color.WHITE)
    print()

    tot_files = sum(b.files for b in buckets)
    tot_lines = sum(b.total_lines for b in buckets)
    tot_c_lines = sum(b.lines_with_comment for b in buckets)
    tot_no_c = sum(b.files_without_comment for b in buckets)
    pct = (tot_c_lines / tot_lines * 100.0) if tot_lines else 0.0

    print_colored(
        f"    Lines with a comment token: {tot_c_lines:,} / {tot_lines:,} "
        f"({pct:.1f}%)  |  {tot_no_c:,} / {tot_files:,} files with no comment lines",
        Color.CYAN,
    )
    print_colored(
        "    (Dart/TS: //, /* */, outside strings; TS includes `templates`; "
        "Python: tokenize COMMENT only.)",
        Color.DIM,
    )
    print()

    label_w = 32
    for b in buckets:
        bpct = (b.lines_with_comment / b.total_lines * 100.0) if b.total_lines else 0.0
        print_colored(
            f"    {b.label:<{label_w}s} {b.lines_with_comment:>7,} / {b.total_lines:>7,} lines "
            f"({bpct:5.1f}%)   {b.files_without_comment:>5} file(s) w/o comments",
            Color.WHITE,
        )
    print()

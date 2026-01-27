"""
Pub.dev lint issue detection and auto-fix.

Checks for issues that pub.dev's stricter analysis (`lints_core`) will
flag, such as dangling library doc comments, unescaped angle brackets,
and unresolvable ``[symbol]`` references in documentation comments.

Usage from publish script:
    issues = check_pubdev_lint_issues(project_dir)
    fixed  = fix_doc_angle_brackets(project_dir)
    fixed += fix_doc_references(project_dir)

Version:   2.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from collections.abc import Iterator
from pathlib import Path

from scripts.modules._utils import print_info

# Directories that pub.dev analyses (matches .pubignore exclusions)
_SCAN_SUBDIRS = ("lib", "bin")

# Matches angle bracket expressions in doc comments:
#   word<content>  e.g. Future<void>, State<T>
#   <content>      e.g. <command>, <tier>
# Excludes content containing backticks (already escaped).
_ANGLE_RE = re.compile(r"(?:\b[\w.]+)?<[^>`]+>")

# Matches [reference] in doc comments that dartdoc tries to resolve as symbols.
# Excludes markdown links [text](url) by requiring no trailing '('.
_DOC_REF_RE = re.compile(r"\[([^\]]+)\](?!\()")

# File extensions that indicate a file name, not a Dart symbol.
_FILE_EXTS = frozenset(
    {".md", ".dart", ".yaml", ".yml", ".json", ".txt", ".html", ".xml"}
)


def check_pubdev_lint_issues(project_dir: Path) -> list[str]:
    """Check for issues that pub.dev's stricter lints will catch.

    Scans ``lib/`` and ``bin/`` for:
    - Dangling library doc comments (``///`` not followed by ``library;``)
    - Unescaped angle brackets in doc comments (interpreted as HTML)
    - Unresolvable ``[reference]`` in doc comments (dartdoc warnings)

    Returns:
        List of human-readable issue descriptions with file:line locations.
    """
    issues: list[str] = []

    for subdir in _SCAN_SUBDIRS:
        scan_dir = project_dir / subdir
        if not scan_dir.exists():
            continue
        for dart_file in scan_dir.rglob("*.dart"):
            content = dart_file.read_text(encoding="utf-8")
            lines = content.split("\n")
            rel_path = dart_file.relative_to(project_dir)

            _check_dangling_library_doc(lines, rel_path, issues)
            _check_angle_brackets(lines, rel_path, issues)
            _check_doc_references(lines, rel_path, issues)

    return issues


def fix_doc_angle_brackets(project_dir: Path) -> int:
    """Auto-fix angle brackets in doc comments by wrapping in backticks.

    Scans ``lib/`` and ``bin/`` for doc comments containing unescaped
    angle brackets (outside code fences and inline backticks) and wraps
    them in backticks so pub.dev analysis won't flag them as HTML.

    Returns:
        Number of lines fixed.
    """
    total_fixed = 0

    for subdir in _SCAN_SUBDIRS:
        scan_dir = project_dir / subdir
        if not scan_dir.exists():
            continue
        for dart_file in scan_dir.rglob("*.dart"):
            fixed = _fix_file_angle_brackets(dart_file, project_dir)
            total_fixed += fixed

    return total_fixed


def fix_doc_references(project_dir: Path) -> int:
    """Auto-fix unresolvable ``[reference]`` in doc comments.

    Scans ``lib/`` and ``bin/`` for doc comments containing ``[text]``
    patterns that ``dart doc`` cannot resolve as Dart symbols (OWASP
    codes, rule names, file names, property names) and replaces them
    with backtick-escaped text.

    Returns:
        Number of references fixed.
    """
    total_fixed = 0

    for subdir in _SCAN_SUBDIRS:
        scan_dir = project_dir / subdir
        if not scan_dir.exists():
            continue
        for dart_file in scan_dir.rglob("*.dart"):
            fixed = _fix_file_doc_references(dart_file, project_dir)
            total_fixed += fixed

    return total_fixed


# ── internal helpers ─────────────────────────────────────────────────


def _unescaped_angle_matches(doc_content: str) -> list[re.Match[str]]:
    """Return angle bracket matches not inside backtick-delimited text."""
    return [
        m
        for m in _ANGLE_RE.finditer(doc_content)
        if doc_content[: m.start()].count("`") % 2 == 0
    ]


def _iter_doc_lines(
    lines: list[str],
) -> Iterator[tuple[int, str]]:
    """Yield ``(index, doc_content)`` for doc lines outside code fences.

    ``doc_content`` is the text after ``///`` with leading/trailing
    whitespace preserved so regex match positions stay valid for
    in-place replacement.
    """
    in_code_block = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("///") and "```" in stripped:
            in_code_block = not in_code_block
            continue
        if in_code_block:
            continue
        if not stripped.startswith("///"):
            in_code_block = False
            continue
        # Keep content after /// unstripped so match offsets are valid
        doc_content = stripped[3:]
        if doc_content.lstrip().startswith("```"):
            continue
        yield i, doc_content


def _check_dangling_library_doc(
    lines: list[str],
    rel_path: Path,
    issues: list[str],
) -> None:
    """Detect ``///`` doc comments not attached to a ``library`` directive."""
    in_header = True
    found_doc_comment = False
    doc_comment_line = 0

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#!"):
            continue
        if stripped.startswith("// ignore"):
            continue
        if stripped.startswith("///") and in_header:
            if not found_doc_comment:
                found_doc_comment = True
                doc_comment_line = i
            continue
        if (
            stripped == "library;" or stripped.startswith("library ")
        ) and found_doc_comment:
            found_doc_comment = False
            break
        if not stripped.startswith("///"):
            in_header = False
            if found_doc_comment:
                issues.append(
                    f"{rel_path}:{doc_comment_line}: "
                    "Dangling library doc comment."
                )
            break


def _check_angle_brackets(
    lines: list[str],
    rel_path: Path,
    issues: list[str],
) -> None:
    """Detect unescaped angle brackets in doc comments."""
    for idx, doc_content in _iter_doc_lines(lines):
        for match in _unescaped_angle_matches(doc_content):
            issues.append(
                f"{rel_path}:{idx + 1}: Angle brackets in "
                f"'{match.group()}' interpreted as HTML. "
                f"Wrap in backticks: `{match.group()}`"
            )


def _fix_file_angle_brackets(
    dart_file: Path, project_dir: Path
) -> int:
    """Fix angle brackets in a single file. Returns count of fixes."""
    content = dart_file.read_text(encoding="utf-8")
    lines = content.split("\n")
    rel_path = dart_file.relative_to(project_dir)
    changed = False
    total_fixes = 0

    for idx, doc_content in _iter_doc_lines(lines):
        fixes = _unescaped_angle_matches(doc_content)
        if not fixes:
            continue

        # Wrap each match in backticks, right-to-left
        prefix_end = lines[idx].index("///") + 3
        new_doc = doc_content
        for match in reversed(fixes):
            s, e = match.start(), match.end()
            new_doc = new_doc[:s] + "`" + match.group() + "`" + new_doc[e:]

        lines[idx] = lines[idx][:prefix_end] + new_doc
        changed = True
        total_fixes += len(fixes)
        print_info(
            f"Fixed {rel_path}:{idx + 1}: "
            f"wrapped {len(fixes)} angle bracket(s)"
        )

    if changed:
        dart_file.write_text("\n".join(lines), encoding="utf-8")

    return total_fixes


# ── doc reference helpers ────────────────────────────────────────────


def _is_unresolvable_ref(text: str) -> str | None:
    """Classify a ``[text]`` doc reference as unresolvable.

    Returns a short reason string if the reference is clearly not a
    resolvable Dart symbol, or ``None`` if it might be valid.

    Only flags patterns that are *never* valid Dart symbol references.
    Lowercase references like ``[paramName]`` are left alone because
    DartDoc resolves them when the symbol is in scope.
    """
    if ":" in text:
        return "contains colon (OWASP/category code)"
    if any(text.endswith(ext) for ext in _FILE_EXTS):
        return "file name reference"
    if "_" in text and text == text.lower():
        return "snake_case (rule name, not a Dart class)"
    return None


def _unresolvable_ref_matches(
    doc_content: str,
) -> list[tuple[re.Match[str], str]]:
    """Return ``[ref]`` matches that are unresolvable, with reasons.

    Skips references already inside backticks.
    """
    results: list[tuple[re.Match[str], str]] = []
    for m in _DOC_REF_RE.finditer(doc_content):
        # Skip if inside backtick-delimited text
        if doc_content[: m.start()].count("`") % 2 != 0:
            continue
        reason = _is_unresolvable_ref(m.group(1))
        if reason:
            results.append((m, reason))
    return results


def _check_doc_references(
    lines: list[str],
    rel_path: Path,
    issues: list[str],
) -> None:
    """Detect unresolvable ``[reference]`` in doc comments."""
    for idx, doc_content in _iter_doc_lines(lines):
        for match, reason in _unresolvable_ref_matches(doc_content):
            ref_text = match.group(1)
            issues.append(
                f"{rel_path}:{idx + 1}: Unresolvable doc reference "
                f"[{ref_text}] ({reason}). "
                f"Replace with: `{ref_text}`"
            )


def _fix_file_doc_references(
    dart_file: Path, project_dir: Path
) -> int:
    """Fix unresolvable doc references in a single file."""
    content = dart_file.read_text(encoding="utf-8")
    lines = content.split("\n")
    rel_path = dart_file.relative_to(project_dir)
    changed = False
    total_fixes = 0

    for idx, doc_content in _iter_doc_lines(lines):
        fixes = _unresolvable_ref_matches(doc_content)
        if not fixes:
            continue

        # Replace [ref] with `ref`, right-to-left to preserve offsets
        prefix_end = lines[idx].index("///") + 3
        new_doc = doc_content
        for match, _reason in reversed(fixes):
            s, e = match.start(), match.end()
            new_doc = new_doc[:s] + "`" + match.group(1) + "`" + new_doc[e:]

        lines[idx] = lines[idx][:prefix_end] + new_doc
        changed = True
        total_fixes += len(fixes)
        print_info(
            f"Fixed {rel_path}:{idx + 1}: "
            f"escaped {len(fixes)} doc reference(s)"
        )

    if changed:
        dart_file.write_text("\n".join(lines), encoding="utf-8")

    return total_fixes

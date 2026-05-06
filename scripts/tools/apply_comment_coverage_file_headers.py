"""
Batch-add file-level overview comments to the lowest comment-density sources.

Uses the same ranking as the publish comment-coverage report
(`collect_per_file_comment_stats`). Idempotent via a short sentinel line so
re-runs skip files already processed.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Sentinel must be a real comment line in each language so re-runs are skipped.
_SENTINEL = "comment-coverage: module overview (batch)"

# --- insertion helpers ---------------------------------------------------------


def _dart_insertion_index(lines: list[str]) -> int | None:
    """Return 0-based index for a new `///` block, or None if the file already has one."""
    i = 0
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    # Existing library dartdoc — do not stack another overview.
    if i < len(lines) and lines[i].startswith("///"):
        return None
    # Leading analyzer ignores must stay first; skip past contiguous ignore lines.
    while i < len(lines):
        raw = lines[i]
        s = raw.strip()
        if not s:
            i += 1
            continue
        low = s.lower()
        if s.startswith("//") and ("ignore_for_file" in low or "ignore:" in s):
            i += 1
            continue
        break
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    # Copyright / banner lines (`//` but not `///`).
    while i < len(lines) and lines[i].startswith("//") and not lines[i].startswith("///"):
        i += 1
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    if i < len(lines) and lines[i].startswith("///"):
        return None
    # Library dartdoc often sits after imports; avoid stacking a second overview.
    if i < len(lines) and lines[i].startswith("import "):
        if _dart_has_dartdoc_between_imports_and_declaration(lines, i):
            return None
    return i


def _dart_has_dartdoc_between_imports_and_declaration(lines: list[str], import_idx: int) -> bool:
    """True when `///` already documents the library before the first top-level declaration."""
    j = import_idx
    while j < len(lines):
        s = lines[j].strip()
        if not s:
            j += 1
            continue
        if s.startswith("import ") or s.startswith("export "):
            j += 1
            continue
        if s.startswith("part "):
            j += 1
            continue
        if s.startswith("///"):
            return True
        if s.startswith("class ") or s.startswith("enum ") or s.startswith("mixin "):
            return False
        if s.startswith("extension ") and " on " in s:
            return False
        if s.startswith("typedef "):
            return False
        # Top-level function / const / final before class — rare; keep scanning.
        j += 1
        if j > 200:
            return False
    return False


def _ts_insertion_index(lines: list[str]) -> int:
    i = 0
    if i < len(lines) and lines[i].startswith("#!"):
        i += 1
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    if i < len(lines) and "coding:" in lines[i] and lines[i].startswith("#"):
        i += 1
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    return i


def _py_insertion_index(lines: list[str]) -> int:
    i = 0
    if i < len(lines) and lines[i].startswith("#!"):
        i += 1
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    if i < len(lines) and "coding:" in lines[i] and lines[i].startswith("#"):
        i += 1
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    return i


def _already_has_sentinel(text: str) -> bool:
    return _SENTINEL in text


def _dart_header(rel: str) -> list[str]:
    topic = _topic_from_path(rel)
    return [
        "/// Module overview (comment coverage pass).",
        f"/// {_SENTINEL}.",
        "///",
        f"/// {topic}",
        "///",
        "/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`",
        "/// and tiers in `lib/src/tiers.dart` where applicable; see `plans/COMMENT_COVERAGE_PLAN.md`.",
        "",
    ]


def _dart_test_header(rel: str) -> list[str]:
    stem = Path(rel).stem
    rule_hint = stem.replace("_test", "").replace("_", " ")
    return [
        "/// Module overview (comment coverage pass).",
        f"/// {_SENTINEL}.",
        "///",
        f"/// Analyzer-backed tests for `{stem}` ({rule_hint}).",
        "///",
        "/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.",
        "",
    ]


def _ts_header(rel: str, *, is_test: bool) -> list[str]:
    if is_test:
        focus = (
            "Extension Jest tests: validates commands, webviews, parsers, and "
            "state against VS Code APIs (often with local mocks)."
        )
    else:
        focus = _topic_from_path(rel)
    return [
        "/**",
        " * Module overview (comment coverage pass).",
        f" * {_SENTINEL}.",
        " *",
        f" * {focus}",
        " */",
        "",
    ]


def _py_header(rel: str) -> list[str]:
    # Metrics count `#` only, not docstrings.
    topic = _topic_from_path(rel)
    return [
        "# Module overview (comment coverage pass).",
        f"# {_SENTINEL}.",
        "#",
        f"# {topic}",
        "#",
        "# See scripts/README.md and plans/COMMENT_COVERAGE_PLAN.md for conventions.",
        "",
    ]


def _topic_from_path(rel: str) -> str:
    rel_posix = rel.replace("\\", "/")
    parts = rel_posix.split("/")
    if rel_posix.startswith("lib/src/rules/"):
        sub = parts[3] if len(parts) > 3 else "rules"
        return f"Saropa lint rule implementations grouped under `{sub}/`."
    if rel_posix.startswith("lib/src/cli/"):
        return "CLI helpers for saropa_lints command-line entrypoints and scans."
    if rel_posix.startswith("lib/src/"):
        return "Core saropa_lints library implementation (utilities, context, or rules support)."
    if rel_posix.startswith("extension/src/commands/"):
        return "VS Code command handlers wired from `package.json` contributions."
    if rel_posix.startswith("extension/src/views/"):
        return "VS Code views: trees, dashboards, or webview HTML builders."
    if rel_posix.startswith("extension/src/vibrancy/"):
        return "Vibrancy UI experiment: scoring, providers, and webview assets."
    if rel_posix.startswith("extension/src/test/"):
        return "TypeScript tests for the Saropa Lints VS Code extension."
    if rel_posix.startswith("extension/src/"):
        return "VS Code extension host code (activation, services, readers)."
    if rel_posix.startswith("scripts/"):
        return "Repository maintenance or publish pipeline script (Python)."
    if rel_posix.startswith("bin/"):
        return "Dart CLI entrypoint for saropa_lints tooling."
    if rel_posix.startswith("packages/"):
        return "Supporting Dart package in the monorepo workspace."
    if rel_posix.startswith("test/"):
        return "Dart tests for saropa_lints behavior and rule coverage."
    return f"Source file `{rel_posix}` in the saropa_lints repository."


def _transform(rel: str, text: str) -> str | None:
    if _already_has_sentinel(text):
        return None
    lines = text.splitlines(keepends=True)
    if not lines:
        return None

    if rel.endswith(".dart"):
        if rel.startswith("test/") or rel.endswith("_test.dart"):
            block = _dart_test_header(rel)
        else:
            block = _dart_header(rel)
        idx = _dart_insertion_index(lines)
        if idx is None:
            return None
        header = _join_header_lines(block)
        return "".join(lines[:idx] + [header] + lines[idx:])

    if rel.endswith(".ts"):
        is_test = "/test/" in rel.replace("\\", "/") or rel.endswith(".test.ts")
        idx = _ts_insertion_index(lines)
        if idx < len(lines) and lines[idx].lstrip().startswith("/**"):
            return None
        block = _ts_header(rel, is_test=is_test)
        header = _join_header_lines(block)
        return "".join(lines[:idx] + [header] + lines[idx:])

    if rel.endswith(".py"):
        idx = _py_insertion_index(lines)
        if idx < len(lines) and lines[idx].startswith('"""'):
            return None
        block = _py_header(rel)
        header = _join_header_lines(block)
        return "".join(lines[:idx] + [header] + lines[idx:])

    return None


def _join_header_lines(lines: list[str]) -> str:
    """Join header fragments with newlines (list items must not include trailing \\n)."""
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."), help="Repo root")
    parser.add_argument(
        "--limit",
        type=int,
        default=150,
        help="Stop after this many files are actually modified (not candidates scanned)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print paths only")
    args = parser.parse_args()
    root: Path = args.root.resolve()

    sys.path.insert(0, str(root))
    from scripts.modules._comment_coverage_report import collect_per_file_comment_stats

    stats = collect_per_file_comment_stats(
        root,
        min_physical_lines=15,
        exclude_fixture_subdir=True,
        progress_to_stderr=False,
    )

    changed = 0
    skipped = 0
    scanned = 0
    for s in stats:
        if changed >= args.limit:
            break
        scanned += 1
        path = root / s.rel_path
        if not path.is_file():
            skipped += 1
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        new_text = _transform(s.rel_path, text)
        if new_text is None:
            skipped += 1
            continue
        if args.dry_run:
            print(s.rel_path)
            changed += 1
            continue
        path.write_text(new_text, encoding="utf-8", newline="")
        changed += 1

    print(
        f"Modified (or listed in dry-run): {changed}, skipped: {skipped}, "
        f"candidates scanned: {scanned} / {len(stats)}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

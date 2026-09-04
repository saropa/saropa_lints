#!/usr/bin/env python3
"""
Migrate ignore comments and analysis_options.yaml from old saropa_lints
rule names to their renamed equivalents.

38 rules were renamed with semantic suffixes to avoid collision with
core Dart/Flutter analyzer lint names. This script rewrites:
  - `// ignore: old_name` → `// ignore: new_name`
  - `// ignore_for_file: old_name` → `// ignore_for_file: new_name`
  - Rule names in `analysis_options.yaml` lint config sections

Usage:
    python scripts/fix_ignores.py <directory>           # dry run
    python scripts/fix_ignores.py <directory> --apply   # rewrite in place

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Complete rename map: old_name → new_name.
# 3 rules were dropped (no new name); they are not in this map.
# Users with ignore comments for dropped rules should remove them.
RENAME_MAP: dict[str, str] = {
    "avoid_classes_with_only_static_members": "avoid_classes_with_only_static_members_with_fix",
    "avoid_dynamic_calls": "avoid_dynamic_calls_extended",
    "avoid_equals_and_hash_code_on_mutable_classes": "avoid_equals_and_hash_code_on_mutable_classes_extended",
    "avoid_implementing_value_types": "avoid_implementing_value_types_extended",
    "avoid_double_and_int_checks": "avoid_double_and_int_checks_extended",
    "avoid_escaping_inner_quotes": "avoid_escaping_inner_quotes_with_fix",
    "avoid_field_initializers_in_const_classes": "avoid_field_initializers_in_const_classes_relaxed",
    "avoid_function_literals_in_foreach_calls": "avoid_function_literals_in_foreach_calls_no_maps",
    "avoid_js_rounded_ints": "avoid_js_rounded_ints_extended",
    "avoid_null_checks_in_equality_operators": "avoid_null_checks_in_equality_operators_extended",
    "avoid_positional_boolean_parameters": "avoid_positional_boolean_parameters_with_fix",
    "avoid_returning_null_for_future": "avoid_returning_null_for_future_strict",
    "avoid_returning_null_for_void": "avoid_returning_null_for_void_with_fix",
    "avoid_returning_this": "avoid_returning_this_with_fix",
    "avoid_setters_without_getters": "avoid_setters_without_getters_local",
    "avoid_shadowing_type_parameters": "avoid_shadowing_type_parameters_class_methods",
    "avoid_single_cascade_in_expression_statements": "avoid_single_cascade_in_expression_statements_with_fix",
    "avoid_types_on_closure_parameters": "avoid_types_on_closure_parameters_with_fix",
    "avoid_unnecessary_containers": "avoid_unnecessary_containers_resolved",
    "avoid_unused_constructor_parameters": "avoid_unused_constructor_parameters_skip_private",
    "avoid_void_async": "avoid_void_async_extended",
    "prefer_asserts_in_initializer_lists": "prefer_asserts_in_initializer_lists_safe",
    "prefer_const_constructors_in_immutables": "prefer_const_constructors_in_immutables_extended",
    "prefer_const_declarations": "prefer_const_declarations_with_fix",
    "prefer_const_literals_to_create_immutables": "prefer_const_literals_to_create_immutables_widget_scoped",
    "prefer_constructors_over_static_methods": "prefer_constructors_over_static_methods_strict",
    "prefer_double_quotes": "prefer_double_quotes_with_fix",
    "prefer_final_fields": "prefer_final_fields_with_fix",
    "prefer_final_locals": "prefer_final_locals_with_fix",
    "prefer_if_elements_to_conditional_expressions": "prefer_if_elements_to_conditional_expressions_null_branch",
    "prefer_initializing_formals": "prefer_initializing_formals_extended",
    "prefer_inlined_adds": "prefer_inlined_adds_strict",
    "prefer_null_aware_method_calls": "prefer_null_aware_method_calls_extended",
    "prefer_relative_imports": "prefer_relative_imports_enforced",
    "prefer_single_quotes": "prefer_single_quotes_strict",
    "secure_pubspec_urls": "secure_pubspec_urls_strict",
    "sort_pub_dependencies": "sort_pub_dependencies_extended",
    "unintended_html_in_doc_comment": "unintended_html_in_doc_comment_strict",
    "unnecessary_library_name": "unnecessary_library_name_with_fix",
    "use_truncating_division": "use_truncating_division_strict",
}

# Dropped rules — the core Dart lint covers these; remove ignore comments.
DROPPED_RULES: frozenset[str] = frozenset({
    "avoid_private_typedef_functions",
    "missing_code_block_language_in_doc_comment",
})

# File extensions to scan for ignore comments.
_DART_GLOBS = ("**/*.dart",)
# YAML files that may contain rule name references.
_YAML_GLOBS = ("**/analysis_options*.yaml",)


def _build_ignore_pattern() -> re.Pattern[str]:
    """Build a regex matching old rule names in ignore comments.

    Matches `// ignore: <name>` and `// ignore_for_file: <name>` where
    <name> appears as a comma-separated entry in the ignore list.
    """
    # Match any old rule name as a whole word in an ignore comment.
    names = "|".join(re.escape(n) for n in sorted(RENAME_MAP))
    return re.compile(rf"\b({names})\b")


def scan_file(path: Path, pattern: re.Pattern[str]) -> list[tuple[int, str, str]]:
    """Find lines with old rule names. Returns (line_num, old, new) triples."""
    hits: list[tuple[int, str, str]] = []
    try:
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return hits

    for i, line in enumerate(content.splitlines(), 1):
        for m in pattern.finditer(line):
            old = m.group(1)
            new = RENAME_MAP.get(old)
            if new:
                hits.append((i, old, new))
    return hits


def rewrite_file(path: Path, pattern: re.Pattern[str]) -> int:
    """Rewrite old rule names in a file. Returns number of replacements."""
    try:
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return 0

    def replacer(m: re.Match[str]) -> str:
        old = m.group(1)
        return RENAME_MAP.get(old, old)

    new_content, count = pattern.subn(replacer, content)
    if count:
        path.write_text(new_content, encoding="utf-8")
    return count


def main() -> None:
    """Entry point."""
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <directory> [--apply]")
        sys.exit(1)

    target = Path(sys.argv[1])
    if not target.is_dir():
        print(f"ERROR: {target} is not a directory.", file=sys.stderr)
        sys.exit(1)

    apply_mode = "--apply" in sys.argv
    pattern = _build_ignore_pattern()

    # Collect all Dart and YAML files to scan.
    files: list[Path] = []
    for glob in _DART_GLOBS + _YAML_GLOBS:
        files.extend(target.rglob(glob.lstrip("**/") if glob.startswith("**/") else glob))

    # Deduplicate and sort for deterministic output.
    files = sorted(set(files))

    total_hits = 0
    total_files = 0

    for path in files:
        if apply_mode:
            count = rewrite_file(path, pattern)
            if count:
                total_hits += count
                total_files += 1
                print(f"  {path}: {count} replacement(s)")
        else:
            hits = scan_file(path, pattern)
            if hits:
                total_files += 1
                for line_num, old, new in hits:
                    total_hits += 1
                    print(f"  {path}:{line_num}: {old} → {new}")

    # Report summary.
    if apply_mode:
        print(f"\nRewrote {total_hits} reference(s) in {total_files} file(s).")
    else:
        if total_hits:
            print(
                f"\nFound {total_hits} stale reference(s) in {total_files} "
                f"file(s). Run with --apply to fix."
            )
        else:
            print("\nNo stale rule name references found.")


if __name__ == "__main__":
    main()

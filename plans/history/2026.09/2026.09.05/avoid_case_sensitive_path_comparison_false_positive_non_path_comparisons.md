# BUG: `avoid_case_sensitive_path_comparison` — False positive on non-path comparisons and root-detection idioms

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_case_sensitive_path_comparison`
File: `lib/src/rules/config/config_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v3

---

## Summary

6 of 7 findings are false positives. The rule fires on:

1. **Filesystem root-detection idiom** (`parent.path == dir.path` / `dir.path != dir.parent.path`) — 3 instances. This is a standard Dart idiom for detecting when directory traversal reaches the root. Both sides come from the same `Directory` API call, so casing is always consistent.

2. **Same-source path comparison** (`cached._manifestPath == manifestPath`) — 1 instance. Both paths are built from the same hardcoded candidate-string templates in the same process.

3. **Dart import URI comparison** (`imp == pathFirst`) — 1 instance. Dart import specifiers are case-sensitive by language spec. This is not a filesystem path comparison.

4. **CLI flag string comparison** (`arg == '--json-file-path'`) — 1 instance. Comparing a command-line argument literal, not a path. The word "path" in the flag name triggered the heuristic.

Only `project_vibrancy.dart:731` was a real issue (fixed separately with `p.equals()`).

---

## Attribution Evidence

```bash
grep -rn "'avoid_case_sensitive_path_comparison'" lib/src/rules/
# (match in config_rules.dart)
```

---

## Reproducer

```dart
// FP 1: Root-detection idiom — not cross-source
var dir = Directory(startPath);
while (dir.path != dir.parent.path) { // LINT — but should NOT lint
  dir = dir.parent;
}

// FP 2: CLI flag comparison — not a path at all
if (arg == '--json-file-path') { ... } // LINT — but should NOT lint
```

---

## Suggested Fix

1. Exempt `==`/`!=` comparisons where both sides are `.path` accessors on the same `Directory` variable (or its `.parent`).
2. Do not fire on string literal comparisons unless the literal looks like a path (contains `/` or `\`).
3. Do not fire on Dart import URI comparisons (values from `ImportDirective.uri`).

---

## Affected Files (FP only)

- `android_manifest_utils.dart:60` — same-source path
- `project_context_project_file.dart:102` — root detection
- `baseline_date.dart:189` — root detection
- `baseline_manager.dart:354` — root detection
- `project_context_import_location.dart:233` — Dart import URI
- `scan_cli_args.dart:584` — CLI flag string

---

## Environment

- saropa_lints version: current (unreleased)

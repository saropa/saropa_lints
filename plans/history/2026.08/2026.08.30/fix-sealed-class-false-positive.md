# Fix: prefer_single_declaration_per_file false positive on sealed classes

`prefer_single_declaration_per_file` incorrectly flagged sealed class hierarchies. Dart requires sealed subtypes to reside in the same library (same file or via `part`), making co-location mandatory — not a style violation. The rule now detects sealed classes in the file and excludes their subtypes from the declaration count.

Closes [#322](https://github.com/saropa/saropa_lints/issues/322).

## Finish Report (2026-08-30)

### Problem

The `prefer_single_declaration_per_file` rule counted all top-level class declarations equally. Files containing a `sealed class` with its required subtypes triggered a false positive, since Dart 3 sealed classes mandate that all direct subtypes exist in the same library.

### Fix

**Sealed hierarchy exemption:**

Two-pass approach in `PreferSingleDeclarationPerFileRule.runWithReporter`:

1. **First pass** — collects the names of all `sealed` class declarations.
2. **Second pass** — any class whose `extends`, `implements`, or `with` clause references a sealed class from the set is excluded from the count.

**Configurable threshold:**

`max_declarations_per_file` (default 1) allows projects to tolerate co-located data classes. The `excessClass` tracking was refactored to report the class that actually exceeds the threshold, not always the 2nd class.

**Sealed hierarchy size nudge:**

`max_sealed_hierarchy_lines` (default 0 = disabled) fires on sealed hierarchy files exceeding the configured line count, suggesting `part`/`part of` to split subtypes.

### Files changed

| File | Change |
|------|--------|
| `lib/src/rules/code_quality/code_quality_prefer_rules.dart` | Sealed-hierarchy detection, `excessClass` fix, size nudge |
| `lib/src/config/max_declarations_config.dart` | Config loader for both thresholds |
| `lib/src/native/config_loader.dart` | Hook config into plugin startup |
| `example/lib/code_quality/prefer_single_declaration_per_file_fixture.dart` | Sealed hierarchy fixture with `extends`, `implements`, multi-level cases |
| `test/config/max_declarations_config_test.dart` | 14 unit tests for both config values |
| `CHANGELOG.md` | Entries under `### Fixed` and `### Added` |

### Testing

- 14 config parser tests pass (both thresholds: null, empty, valid, floor, disabled, combined).
- Fixture covers `extends`, `implements`, and multi-level sealed hierarchies.

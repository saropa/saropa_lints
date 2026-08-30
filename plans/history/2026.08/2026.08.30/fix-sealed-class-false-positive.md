# Fix: prefer_single_declaration_per_file false positive on sealed classes

`prefer_single_declaration_per_file` incorrectly flagged sealed class hierarchies. Dart requires sealed subtypes to reside in the same library (same file or via `part`), making co-location mandatory — not a style violation. The rule now detects sealed classes in the file and excludes their subtypes from the declaration count. Additionally, the threshold is now configurable via `max_declarations_per_file:` in `analysis_options_custom.yaml`.

Closes [#322](https://github.com/saropa/saropa_lints/issues/322).

## Finish Report (2026-08-30)

### Problem

The `prefer_single_declaration_per_file` rule counted all top-level class declarations equally. Files containing a `sealed class` with its required subtypes triggered a false positive, since Dart 3 sealed classes mandate that all direct subtypes exist in the same library. Users had no workaround short of suppressing the rule entirely. The hardcoded threshold of 1 also prevented projects with small co-located data classes from using the rule without suppression.

### Fix

**Sealed hierarchy exemption:**

Added a two-pass approach to `PreferSingleDeclarationPerFileRule.runWithReporter`:

1. **First pass** — collects the names of all `sealed` class declarations in the compilation unit into a `Set<String>`.
2. **Second pass** — when counting major declarations, any class whose `extends`, `implements`, or `with` clause references a sealed class from the set is excluded from the count.

A new helper `_extendsSealedClassInFile` performs the sealed-hierarchy check by inspecting `ExtendsClause`, `ImplementsClause`, and `WithClause`.

**Configurable threshold:**

Added `max_declarations_per_file` config support. The default remains 1 (original behavior). Projects can set a higher value in `analysis_options_custom.yaml` to allow co-located data classes.

### Files changed

| File | Change |
|------|--------|
| `lib/src/rules/code_quality/code_quality_prefer_rules.dart` | Sealed-hierarchy detection, `with` clause support, configurable threshold via `maxDeclarationsPerFile` |
| `lib/src/config/max_declarations_config.dart` | New config loader for `max_declarations_per_file:` |
| `lib/src/native/config_loader.dart` | Hook `loadMaxDeclarationsConfig` into plugin startup |
| `example/lib/code_quality/prefer_single_declaration_per_file_fixture.dart` | Sealed class hierarchy fixture with `extends` and `implements` cases |
| `test/config/max_declarations_config_test.dart` | 8 unit tests for config parsing edge cases |
| `CHANGELOG.md` | Entries under `### Fixed` and `### Added` in `[15.2.5] — Unreleased` |

### Testing

- Existing rule instantiation smoke test passes.
- 8 new config parser tests pass (null, empty, missing key, valid value, floor at 1, among other config, commented-out).
- Fixture contains a sealed class with subtypes using both `extends` and `implements`.

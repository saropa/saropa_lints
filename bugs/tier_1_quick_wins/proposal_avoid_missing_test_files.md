# PROPOSAL: Flag Library Files With No Corresponding Test File

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_missing_test_files` — a cross-file check that flags a `lib/src/foo.dart` file when the project has no matching `test/foo_test.dart` (or nested equivalent, e.g. `lib/src/category/foo.dart` → `test/category/foo_test.dart`). The diagnostic is reported on the library file itself, pointing at a test file that does not exist.

**Closes gap:** DCM `avoid-missing-test-files` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Untested source files are a common and expensive gap: a file ships, nobody notices it has zero coverage, and the first signal is a production regression. DCM's `avoid-missing-test-files` catches this at review time by enforcing the project's own test-file naming convention (`<name>.dart` → `<name>_test.dart`) rather than requiring a coverage tool. saropa_lints already does cross-file analysis elsewhere (unused files, circular deps — see `saropa-lints-diagnostics-and-tooling` skill), so this fits the existing `ProjectContext` cross-file infrastructure rather than requiring new machinery.

---

## Detection / Behavior

For each analyzed file under `lib/` (or `lib/src/`), compute the expected test file path by mirroring the directory structure under `test/` and appending `_test` to the basename. If that file does not exist in the project's file set, report a diagnostic on the library file's first line (or class/top-level declaration).

### Should flag (bad code)

```dart
// lib/src/utils/currency_formatter.dart
// LINT — no corresponding test/utils/currency_formatter_test.dart found
class CurrencyFormatter {
  String format(num value) => '\$$value';
}
```

### Should pass (good code)

```dart
// lib/src/utils/currency_formatter.dart
// OK — test/utils/currency_formatter_test.dart exists in the project
class CurrencyFormatter {
  String format(num value) => '\$$value';
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: This is a project-hygiene signal, not a correctness or security issue, and it will fire loudly on any codebase without full test coverage (most real-world projects, including large legacy ones). It needs to be opt-in/low-tier so teams can adopt it deliberately rather than being flooded on first run. Pedantic matches saropa's placement for aspirational, high-noise, high-value-when-adopted rules.

---

## Edge Cases

1. **Barrel/export-only files** (`lib/src/all_rules.dart`-style files that only `export` other files) — should pass; no meaningful unit to test. Detect via "file contains only `export`/`import` directives, no declarations."
2. **`main.dart` / entry-point files** — should pass by default (typically covered by widget/integration tests, not unit tests); allow an exclude-glob config option.
3. **Files under `lib/` that are pure data/config classes with no logic** (e.g. a `const` list of strings) — needs discussion; may want a size/complexity threshold before requiring a test file, to avoid demanding tests for trivial constants files.
4. **Test file exists but under a different naming convention** (`foo_dart_test.dart`, `test_foo.dart`) — should pass only for the exact `<name>_test.dart` convention; document the convention clearly so teams using a different pattern don't get false positives — configurable suffix pattern is a reasonable follow-up.
5. **Generated files** (`.g.dart`, `.freezed.dart`) — should pass; never expect a test file for generated code.
6. **Files inside `example/` or other excluded analysis roots** — should pass; respect the same exclusion list used elsewhere (`analysis_options.yaml` excludes).

---

## Alternatives Considered

- **Coverage-percentage based check instead of file-existence check** — rejected; requires running `dart test --coverage` and parsing lcov output, which is a fundamentally different (execution-based) mechanism outside a static-AST lint rule's scope. File-existence matches DCM's actual behavior and is analyzable statically.
- **Report on the missing test file's "would-be" location instead of the library file** — rejected; the library file is the actionable one is a normal diagnostic target, and DCM reports on the source file too.

---

## Decision

---

## Implementation Notes

Cross-file check — needs `ProjectContext` file-set awareness (see `lib/src/rules/architecture/structure_rules.dart` and existing cross-file rules) rather than a single-file AST visitor.

---

## Commits

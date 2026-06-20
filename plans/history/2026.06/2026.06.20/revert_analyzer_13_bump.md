# Revert analyzer ^13.3.0 bump back to ^12.1.0

An uncommitted working-tree edit raised the `analyzer` dependency cap from `^12.1.0` to `^13.3.0`, against an explicit in-repo guard comment. Analyzer 13 renamed the public AST classes the package is built on, leaving ~912 references across ~148 `lib/` files uncompilable; the change was reverted and the guard comment hardened.

## Finish Report (2026-06-20)

### Defect

A working-tree change to `pubspec.yaml` set `analyzer: ^13.3.0` (HEAD/v14.0.6 ships `^12.1.0`). The fresh resolution pulled analyzer 13.3.0, which renamed the public AST surface in `package:analyzer/dart/ast/ast.dart` with no deprecated aliases:

- `NamedExpression` → `NamedArgument`
- `SimpleFormalParameter` → `RegularFormalParameter`
- `DefaultFormalParameter` → removed; `FormalParameter.parameter` getter gone

Argument lists now expose elements typed `Argument` rather than `Expression`/`NamedExpression`. Every rule and fix that inspects call arguments or formal parameters stopped resolving — ~912 references across ~148 files in `lib/`, plus the test tree.

The triggering report, `reports/2026.06/2026.06.20/lint_report.log`, captured only 52 errors across 7 test files because those were the files the IDE analysis server had loaded; the break was package-wide, not test-local.

### Root cause

The bump ignored a pre-existing guard in `pubspec.yaml` directly above the constraint: the cap was held at analyzer 12 because analyzer 13's `meta ^1.18.3` floor exceeds the `meta` version Flutter stable pins inside its SDK, which would make `saropa_lints` unresolvable in any Flutter-stable app. The bump introduced a second, independent failure (the AST renames) on top of that resolution blocker.

### Fix

- `pubspec.yaml` — constraint reverted to `analyzer: ^12.1.0`.
- `pubspec.lock` — restored to HEAD (`analyzer 12.1.0`) via `git checkout`.
- `dart pub get` — re-resolved cleanly to analyzer 12.1.0.
- `pubspec.yaml` — replaced the terse two-line warning with a boxed `HARD STOP` block that names both failure modes (the `meta ^1.18.3` Flutter-stable blocker and the analyzer-13 AST renames, with the specific class mappings and the ~912-reference/~148-file migration cost) so a future bump is recognized as a full source migration rather than a constraint change.

### Verification

`dart analyze` on the four previously-broken test files
(`image_filter_quality_detection_test.dart`, `listview_extent_metadata_rules_test.dart`,
`avoid_builder_index_out_of_bounds_behavior_test.dart`,
`require_error_widget_extension_method_test.dart`) → "No issues found!" (exit 0).

### Scope / net effect

The published constraint is identical to HEAD/v14.0.6 (`^12.1.0`); the lockfile matches HEAD. The only net difference from the shipped release is the hardened guard comment in `pubspec.yaml`. No rule logic, tier assignment, `LintImpact`, or quick fix changed.

### Notes for the future

Bumping to analyzer 13 is not a constraint edit. It requires (a) Flutter stable shipping `meta ^1.18.3` so consumers can resolve, and (b) migrating the ~912 AST references to the renamed classes. Both must land together; doing only the constraint bump breaks the build and Flutter-stable consumers simultaneously.

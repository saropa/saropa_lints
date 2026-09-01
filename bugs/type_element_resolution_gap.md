# Bug: `.constructorName.type.element` bypasses usesTypeResolution integrity test

## Status: Open

## Summary

The `usesTypeResolution` integrity test (`test/integrity/uses_type_resolution_test.dart`)
does not catch `.constructorName.type.element` — a type-resolution API accessed via
`NamedType.element` on constructor names. 14 rule files use this pattern without
declaring `usesTypeResolution => true`, meaning those rules may silently fail when
run in the light analysis lane (where type resolution is skipped).

## Affected files

1. `lib/src/rules/architecture/dependency_injection_rules.dart`
2. `lib/src/rules/media/image_rules.dart`
3. `lib/src/rules/packages/dio_rules.dart`
4. `lib/src/rules/packages/flame_rules.dart`
5. `lib/src/rules/packages/getx_rules.dart`
6. `lib/src/rules/stylistic/stylistic_error_testing_rules.dart`
7. `lib/src/rules/stylistic/stylistic_widget_rules.dart`
8. `lib/src/rules/widget/build_method_rules.dart`
9. `lib/src/rules/widget/dialog_snackbar_rules.dart`
10. `lib/src/rules/widget/forms_rules.dart`
11. `lib/src/rules/widget/scroll_rules.dart`
12. `lib/src/rules/widget/ui_ux_rules.dart` (partially fixed — `.superclass.element` rules done)
13. `lib/src/rules/widget/widget_lifecycle_rules.dart` (partially fixed)
14. `lib/src/rules/widget/widget_patterns_ux_rules.dart` (partially fixed)

## Root cause

The regex `_resolvedTypePatterns` catches `.staticElement`, `.declaredElement`, etc.
but not bare `.element` accessed on `NamedType` nodes. The `.superclass.element`
variant was added to the regex in 2026-09-01, but `.constructorName.type.element`
(the far more common path) was deferred because fixing all 14 files is a bulk change.

## Fix

1. Add `|\.constructorName\.type\.element\b` to `_resolvedTypePatterns`
2. For each of the 14 files, find every rule class that uses `.type.element` and
   flip its `usesTypeResolution` to `true`
3. Run the integrity test to verify

## Impact

Rules with `usesTypeResolution => false` that access `.element` will get `null`
when run without type resolution, silently skipping their checks. This is a
correctness bug (missed lint findings), not a crash.

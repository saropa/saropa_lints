# Bug: `.constructorName.type.element` bypasses usesTypeResolution integrity test

## Status: Fixed

## Summary

The `usesTypeResolution` integrity test (`test/integrity/uses_type_resolution_test.dart`)
does not catch `.constructorName.type.element` — a type-resolution API accessed via
`NamedType.element` on constructor names. 12 rule files use this pattern without
declaring `usesTypeResolution => true`, meaning those rules silently produce zero
findings when run in the light analysis lane (where type resolution is skipped).

An additional 23 files use the same pattern but already declare the flag — they are
unaffected.

## Affected files (12)

1. `lib/src/rules/architecture/dependency_injection_rules.dart`
2. `lib/src/rules/core/compound_performance_patterns.dart`
3. `lib/src/rules/media/image_rules.dart`
4. `lib/src/rules/packages/dio_rules.dart`
5. `lib/src/rules/packages/flame_rules.dart`
6. `lib/src/rules/packages/getx_rules.dart`
7. `lib/src/rules/stylistic/stylistic_error_testing_rules.dart`
8. `lib/src/rules/stylistic/stylistic_widget_rules.dart`
9. `lib/src/rules/widget/build_method_rules.dart`
10. `lib/src/rules/widget/dialog_snackbar_rules.dart`
11. `lib/src/rules/widget/forms_rules.dart`
12. `lib/src/rules/widget/scroll_rules.dart`

## Root cause

The regex `_resolvedTypePatterns` in the integrity test catches `.staticElement`,
`.declaredElement`, `.superclass.element`, etc. but not `.constructorName.type.element`
— the most common path to `NamedType.element`. The `.superclass.element` variant was
added 2026-09-01, but `.constructorName.type.element` was deferred as a bulk change.

## Fix

1. Add `.constructorName.type.element` detection to `_resolvedTypePatterns` in
   `test/integrity/uses_type_resolution_test.dart`
2. For each of the 12 files, add `@override bool get usesTypeResolution => true;`
   to every rule class that uses `.constructorName.type.element`
3. Run the integrity test to verify — both directions:
   - **Forward test** (line 48): files using resolved APIs must declare the flag
   - **Inverse test** (line 78): files declaring the flag must actually use resolved
     APIs. After the regex broadens, some files previously passing may now need review

### Regex considerations

The proposed `\.constructorName\.type\.element\b` is the precise chain. A broader
`\.type\.element\b` would also catch `el.type.element` (2 occurrences in
`flutter_sdk_migration_rules.dart`, already flagged), but risks false positives on
non-resolution `.type.element` access if any exists. The narrow pattern is safer;
the broader one is more durable against future access-pattern variations.

## Impact

Rules with `usesTypeResolution => false` that access `.element` get `null` in the
light lane, silently skipping their checks. With 12 affected files — spanning widget,
package, architecture, and stylistic categories — this is a significant coverage gap
in light-lane analysis, not a minor correctness nit. No crash, but entire rule files
produce zero findings in the fast path.

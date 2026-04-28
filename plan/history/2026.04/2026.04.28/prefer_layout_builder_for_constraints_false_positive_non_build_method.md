# BUG: `prefer_layout_builder_for_constraints` false positive outside `build()`  

**Status: Resolved**  
Created: 2026-04-28  
Resolved: 2026-04-28  
Rule: `prefer_layout_builder_for_constraints`

## Original issue

The rule reported `MediaQuery.of(context).size.{width,height}` in non-build scopes (for example `didChangeDependencies`, setup helpers, and async callbacks), where replacing with `LayoutBuilder` is not structurally applicable.

## Implemented fix

- Added non-build scope gating in `PreferLayoutBuilderForConstraintsRule` so diagnostics are skipped when reads occur in:
  - lifecycle methods (`initState`, `didChangeDependencies`, `didUpdateWidget`, `dispose`, `reassemble`, `deactivate`, `activate`)
  - methods that are not `build` and do not declare a `BuildContext` parameter
  - function expressions/closures without a `BuildContext` parameter
- Kept diagnostics active for build-phase contexts and builder callbacks that do take `BuildContext`.
- Updated rule DartDoc to document the non-build carve-out.

## Regression coverage

- Extended fixture with:
  - non-build lifecycle snapshot case (`didChangeDependencies` helper) as non-linting
  - async callback snapshot case (`Future.delayed`) as non-linting
  - `AnimatedBuilder.builder` callback case as linting (true-positive guard)
- Updated fixture marker-count assertion accordingly.

## Validation

- `dart test test/prefer_layout_builder_for_constraints_fixture_test.dart` passed.
- `dart test test/widget_layout_rules_test.dart` passed.

## Notes

This resolves the false-positive class captured in downstream `contacts` initialization flows where screen dimensions are intentionally captured outside build for one-time controller setup.

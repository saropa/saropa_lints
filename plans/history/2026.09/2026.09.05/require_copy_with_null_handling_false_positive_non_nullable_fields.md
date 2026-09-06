# BUG: `require_copy_with_null_handling` — fires on copyWith with non-nullable fields only

**Status: Fixed**

<!-- Status values: Open -> Investigating -> Fix Ready -> Closed -->

Created: 2026-09-05
Rule: `require_copy_with_null_handling`
File: `lib/src/rules/packages/equatable_rules.dart` (line ~903)
Severity: High (forces `// ignore:` workaround on correct code)
Rule version: v2

---

## Summary

The rule warns that `copyWith` using `??` cannot set nullable fields to null. However, it fires on `copyWith` methods where ALL fields using `??` are non-nullable types (e.g. `bool`). Non-nullable fields cannot and should not be set to null, so the `??` pattern is correct and sufficient. The sentinel/wrapper pattern the rule suggests adds unnecessary complexity for non-nullable fields.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive -- rule IS defined here
grep -rn "'require_copy_with_null_handling'" lib/src/rules/
# Result:
# lib/src/rules/packages/equatable_rules.dart:923:    'require_copy_with_null_handling',
```

**Emitter registration:** `lib/src/rules/packages/equatable_rules.dart:923`
**Rule class:** `RequireCopyWithNullHandlingRule` -- registered at line 903
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// All fields are non-nullable bool -- ?? is the correct pattern here.
class MentalModelViewOptions {
  final bool showDetails;
  final bool showExamples;
  final bool isExpanded;

  const MentalModelViewOptions({
    this.showDetails = false,
    this.showExamples = false,
    this.isExpanded = false,
  });

  MentalModelViewOptions copyWith({ // LINT -- but should NOT lint
    bool? showDetails,
    bool? showExamples,
    bool? isExpanded,
  }) {
    return MentalModelViewOptions(
      showDetails: showDetails ?? this.showDetails,
      showExamples: showExamples ?? this.showExamples,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
```

**Frequency:** Always -- fires on every `copyWith` using `??`, regardless of field nullability.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic -- all fields are non-nullable `bool`, so `??` is the correct and complete pattern. There is no null-setting problem to solve. |
| **Actual** | `[require_copy_with_null_handling] copyWith with ?? operator cannot set nullable fields to null. Standard copyWith pattern can't distinguish between "not provided" and "explicitly null". Use a sentinel value or wrapper class...` reported at line 62 |

---

## AST Context

```
ClassDeclaration (MentalModelViewOptions)
  └─ MethodDeclaration (copyWith)
      └─ FormalParameterList
          └─ DefaultFormalParameter (bool? showDetails)  <- nullable parameter
      └─ Block
          └─ ReturnStatement
              └─ InstanceCreationExpression (MentalModelViewOptions(...))
                  └─ BinaryExpression (showDetails ?? this.showDetails)  <- ?? usage flagged
```

---

## Root Cause

The rule detects `copyWith` methods that use the `??` operator and warns about the inability to set nullable fields to null. However, it does not check whether the CLASS fields (the targets of the copy) are actually nullable. When every field using `??` in the body maps to a non-nullable class field, there is no "set to null" use case -- the `??` pattern is correct by construction.

The diagnostic message itself says "cannot set nullable fields to null" -- but when there ARE no nullable fields, the warning is vacuous.

---

## Suggested Fix

Before emitting the diagnostic, check the nullability of the class fields that correspond to the `??` expressions in the copyWith body:

1. For each `paramName ?? this.paramName` expression, resolve `this.paramName` to its field declaration.
2. Check if the field's declared type is nullable (`T?`).
3. If ALL fields referenced by `??` are non-nullable, skip the diagnostic -- the sentinel/wrapper pattern adds no value.
4. Only emit the diagnostic when at least one field referenced by `??` IS nullable (where the caller genuinely cannot distinguish "not provided" from "set to null").

---

## Fixture Gap

The fixture should include:

1. **copyWith with only non-nullable fields** -- expect NO lint (currently missing)
2. **copyWith with at least one nullable field using ??** -- expect LINT
3. **copyWith with mixed nullable and non-nullable fields** -- expect LINT (nullable fields still have the problem)
4. **copyWith using sentinel pattern** -- expect NO lint (likely exists)

---

## Environment

- saropa_lints version: current
- Triggering project/file: `d:\src\contacts\lib\views\static_data\mental_model_view_screen.dart:62`

---

## Finish Report (2026-09-05)

`RequireCopyWithNullHandlingRule` (`lib/src/rules/packages/equatable_rules.dart`) previously flagged any `copyWith` method using `paramName ?? this.paramName` regardless of whether the underlying class field was nullable. Non-nullable fields (e.g. `bool`) can never legitimately be set to null, so `??` was already the complete, correct pattern for them -- the rule's sentinel/wrapper suggestion was a false positive for these cases.

**Fix:** `runWithReporter` now collects the set of `??`-handled parameters that fire the existing body-source regex match, then calls a new helper, `_collectNullableFieldNames`, which walks up from the `copyWith` `MethodDeclaration` to its enclosing `ClassDeclaration` and collects field names declared with a nullable type (via the existing `isOuterTypeNullable()` AST-token check). The diagnostic is now only emitted when at least one flagged parameter corresponds to a field that is actually nullable. Field-member iteration uses the `bodyMembers` compat extension from `lib/src/analyzer_compat.dart` (not raw `enclosingClass.body.members`), matching the codebase convention for surviving analyzer API churn between v9-v12 (`ClassDeclaration.members` moved onto `ClassBody` in analyzer 12, and v9 lacks `.body` entirely without a feature gate).

**Verification (rung 3, `scan --resolve`):** the fixture `example_packages/lib/packages/require_copy_with_null_handling_fixture.dart` was rewritten -- the previous BAD case wrapped `copyWith` in a local function nested inside a top-level function, which the rule's `addMethodDeclaration` visitor (class-member-only) can never see, so it was silently dead regardless of this fix. The rewritten fixture uses real class methods:
- `UserProfile.copyWith` (nullable `nickname` field) -- fires, confirming the true-positive case is intact.
- `MentalModelViewOptions.copyWith` (all-non-nullable fields, the reported FP shape) -- does not fire, confirming the fix.
- `Settings.copyWith` (mixed nullable `theme` + non-nullable `enabled`) -- fires, confirming a genuinely nullable field is still caught even alongside non-nullable ones.
- `User.copyWith` (pre-existing `Optional<T>` wrapper GOOD case) -- does not fire, unaffected.

`dart run saropa_lints scan . --tier comprehensive --files example_packages/lib/packages/require_copy_with_null_handling_fixture.dart --resolve --format json` reports exactly 2 `require_copy_with_null_handling` diagnostics, at lines 121-123 and 163-165, matching the two BAD cases above. `dart test test/rules/packages/equatable_rules_test.dart` and `dart test test/integrity/saropa_lints_test.dart` both pass (32/32 and 24/24 respectively).

**Known limitations (documented in code, accepted as out of scope for a heuristic name-matching rule):** the field-nullability check matches by NAME, not by resolved element, so it misses inherited fields declared on a superclass, a `copyWith` parameter renamed relative to its backing field, and a field whose nullability is hidden behind a `typedef` expansion (the AST-token check in `isOuterTypeNullable()` only sees a literal `?`). These were raised in code review and judged acceptable for the common case rather than warranting full type resolution.

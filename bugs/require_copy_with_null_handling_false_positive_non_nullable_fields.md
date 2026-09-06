# BUG: `require_copy_with_null_handling` — fires on copyWith with non-nullable fields only

**Status: Open**

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

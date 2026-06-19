# BUG: `avoid_unassigned_fields` — Fires on field initialized by `required this.field` named formal parameter

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `avoid_unassigned_fields`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~1503)
Severity: False positive — High (fires on a universal Dart constructor pattern: `required this.field` in a const/generative constructor; forces teams to disable the rule)
Rule version: v4 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule flags a nullable field as "declared without an initializer and no constructor or method assigns it a value" even when the field IS initialized by a `required this.field` (or optional `this.field`) named formal parameter in the constructor. The detection only recognizes a `FieldFormalParameter` when it is a *positional* parameter; for *named* and *optional* parameters the analyzer wraps the `FieldFormalParameter` inside a `DefaultFormalParameter`, and the rule's `is FieldFormalParameter` check returns false for that wrapper, so the field is treated as unassigned.

Expected: no diagnostic — an initializing formal assigns the field. Actual: `[avoid_unassigned_fields]` reported on each such field.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'avoid_unassigned_fields'" lib/src/rules/
# Result:
# lib/src/rules/code_quality/code_quality_variables_rules.dart:1464:    'avoid_unassigned_fields',

# Negative — rule is NOT in the triggering sibling repo
grep -rn "avoid_unassigned_fields" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# Result: 0 matches (the name appears only in that project's analysis_options.yaml)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:1464`
**Rule class:** `AvoidUnassignedFieldsRule` (declared at line 1447), registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (the saropa_lints `custom_lint` plugin)

---

## Reproducer

From `saropa_drift_advisor/lib/src/server/mutation_tracker.dart`, simplified to the minimum that triggers the bug:

```dart
final class MutationRowSnapshots {
  const MutationRowSnapshots({
    required this.beforeRows,
    required this.afterRows,
  });

  final List<Map<String, dynamic>>? beforeRows; // LINT (avoid_unassigned_fields) — but the field IS assigned by `required this.beforeRows`
  final List<Map<String, dynamic>>? afterRows;   // LINT — same false positive
}
```

Both fields are nullable (`?`) and have no declaration-site initializer, so they enter the rule's `nullableFields` candidate set. Both are initialized only through the `required this.<name>` named initializing formals. Reading either field returns the value passed to the constructor, never the nullable default — so the diagnostic's premise ("Reading this field returns the default value") is false here.

For contrast, the same fields declared with a *positional* initializing formal do NOT lint:

```dart
final class Ok {
  const Ok(this.beforeRows, this.afterRows); // OK — positional FieldFormalParameter is recognized

  final List<int>? beforeRows; // OK
  final List<int>? afterRows;  // OK
}
```

**Frequency:** Always, for any nullable field whose only assignment is a *named* or *optional* `this.field` formal parameter (the dominant style for const data classes — every `required this.x` named parameter). Positional `this.field` parameters are unaffected.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `beforeRows` and `afterRows` are assigned via named initializing formals (`required this.beforeRows` / `required this.afterRows`) |
| **Actual** | `[avoid_unassigned_fields] Field declared without an initializer and no constructor or method assigns it a value. …` reported on `beforeRows` and on `afterRows` |

---

## AST Context

For a *named* initializing formal, the analyzer wraps the `FieldFormalParameter` in a `DefaultFormalParameter` (the wrapper that carries the `required`/default-value information). The rule iterates `member.parameters.parameters`, which yields the wrapper, not the inner node:

```
ClassDeclaration (MutationRowSnapshots)
  └─ ConstructorDeclaration (const MutationRowSnapshots({...}))
      └─ FormalParameterList
          └─ DefaultFormalParameter            ← what `member.parameters.parameters` yields
              ├─ (kind: required, named)
              └─ FieldFormalParameter (this.beforeRows)   ← the node the rule checks for, but never reaches
  └─ FieldDeclaration
      └─ VariableDeclaration (beforeRows)       ← node reported here (false positive)
```

Compare the positional case, which has no wrapper and so works:

```
ConstructorDeclaration (Ok(this.beforeRows, this.afterRows))
  └─ FormalParameterList
      └─ FieldFormalParameter (this.beforeRows)  ← `is FieldFormalParameter` is true → field recorded as assigned
```

---

## Root Cause

In `AvoidUnassignedFieldsRule.runWithReporter`, the constructor-parameter scan does a direct (un-unwrapped) type test:

`lib/src/rules/code_quality/code_quality_variables_rules.dart:1503-1507`

```dart
for (final FormalParameter param in member.parameters.parameters) {
  if (param is FieldFormalParameter) {
    assignedFields.add(param.name.lexeme);
  }
}
```

`member.parameters.parameters` returns the top-level `FormalParameter` for each slot. For a **named** parameter (`{required this.beforeRows}`) or an **optional positional** parameter (`[this.beforeRows]`), that top-level node is a `DefaultFormalParameter`, whose actual parameter is reachable only via `.parameter`. The `is FieldFormalParameter` test is therefore false, the field name is never added to `assignedFields`, and the field — being nullable with no initializer (collected at lines 1481-1493) — is reported at lines 1523-1527.

Only a **required positional** parameter (`this.beforeRows`) is an un-wrapped `FieldFormalParameter`, which is why the positional reproducer above does not lint and the named one does. This is a pure parameter-shape gap, not a type-resolution issue.

### Hypothesis A (confirmed): named/optional initializing formals are not unwrapped

The loop never unwraps `DefaultFormalParameter`, so it misses every `this.field` that is named or optional-positional. This matches the reproducer exactly: the const constructor uses `{required this.beforeRows, required this.afterRows}`, both named, both wrapped.

The correct unwrap idiom already exists elsewhere in the same file — see `_declaredTypeName` at line 553-555:

```dart
FormalParameter inner = param;
if (inner is DefaultFormalParameter) inner = inner.parameter;
```

The constructor scan simply does not apply it.

### Hypothesis B (ruled out): `super.field` formals

`super.x` parameters are a related but separate gap. A `super.field` formal is a `SuperFormalParameter` (also wrappable in `DefaultFormalParameter`), which the current loop likewise does not handle. The reproducer does not exercise this, but the fix should cover it for completeness since a field forwarded to a super constructor via `super.x` is likewise assigned, not unassigned.

---

## Suggested Fix

Unwrap `DefaultFormalParameter` before the type test, and treat both `FieldFormalParameter` (`this.x`) and `SuperFormalParameter` (`super.x`) as assigning the named field. Reuse the existing idiom from line 553-555.

`lib/src/rules/code_quality/code_quality_variables_rules.dart:1503-1507`

**Before:**
```dart
for (final FormalParameter param in member.parameters.parameters) {
  if (param is FieldFormalParameter) {
    assignedFields.add(param.name.lexeme);
  }
}
```

**After (intent — final names/style to match the file's conventions):**
```dart
// A field is assigned when a constructor declares it via an initializing
// formal (`this.x`) or a super formal (`super.x`). For NAMED and OPTIONAL
// parameters the analyzer wraps the real parameter in a
// DefaultFormalParameter, so unwrap before the type test — otherwise a
// `required this.x` named parameter (the common const-data-class pattern)
// is missed and the field is wrongly reported as unassigned.
for (final FormalParameter param in member.parameters.parameters) {
  final FormalParameter inner =
      param is DefaultFormalParameter ? param.parameter : param;
  if (inner is FieldFormalParameter) {
    assignedFields.add(inner.name.lexeme);
  } else if (inner is SuperFormalParameter) {
    assignedFields.add(inner.name.lexeme);
  }
}
```

Both `FieldFormalParameter` and `SuperFormalParameter` expose `name` as a `Token`, so `inner.name.lexeme` is valid for each. `SimpleFormalParameter` and `FunctionTypedFormalParameter` fall through unchanged.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/avoid_unassigned_fields_fixture.dart` should include constructors that assign nullable fields via every initializing-formal shape:

1. **Named required initializing formal** — `const C({required this.x});` with `final T? x;` — expect NO lint (the exact reproducer)
2. **Named optional initializing formal** — `const C({this.x});` with `final T? x;` — expect NO lint
3. **Optional positional initializing formal** — `const C([this.x]);` with `final T? x;` — expect NO lint
4. **Positional required initializing formal** — `const C(this.x);` with `final T? x;` — expect NO lint (regression guard; already works today)
5. **Super formal** — subclass forwarding `super.x` for an inherited nullable field — expect NO lint
6. **Genuinely unassigned nullable field** — `final T? x;` with no initializer, no formal, no body assignment — expect LINT (ensure the fix does not suppress the true positive)

---

## Changes Made

`lib/src/rules/code_quality/code_quality_variables_rules.dart` (`AvoidUnassignedFieldsRule.runWithReporter`, constructor-parameter scan) — the loop now unwraps `DefaultFormalParameter` before the type test and treats both `FieldFormalParameter` (`this.x`) and `SuperFormalParameter` (`super.x`) as assigning the named field. This reuses the existing unwrap idiom from `_declaredTypeName` (line ~553) and matches the `SuperFormalParameter` handling already used in `compile_time_syntax_rules.dart` / `class_constructor_rules.dart` / `documentation_rules.dart`. `SimpleFormalParameter` and `FunctionTypedFormalParameter` fall through unchanged, so genuinely unassigned nullable fields still lint.

---

## Tests Added

`example/lib/code_quality/avoid_unassigned_fields_fixture.dart` — added the six fixture shapes from the Fixture Gap section: named-required, named-optional, optional-positional, positional-required, and super-formal initializing formals (all expect NO lint), plus a genuinely unassigned nullable field that still expects the lint (regression guard for the true positive).

Note: the scan-CLI / full-package build could not be exercised at fix time because unrelated in-progress edits from other workstreams in the same working tree (`exception_rules.dart` and the `move_variable_outside_iteration` rework in `code_quality_variables_rules.dart`) leave the package non-compiling. The fix is isolated, syntactically valid, and matches proven idioms already in the codebase.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-19)

### Defect

`avoid_unassigned_fields` reported a nullable field as unassigned even when a constructor initialized it through a `required this.field` (or optional `this.field`) named formal parameter — the dominant style for const data classes. The root cause was a parameter-shape gap: the constructor-parameter scan ran a direct `is FieldFormalParameter` test against `member.parameters.parameters`. For named and optional parameters the analyzer wraps the initializing formal in a `DefaultFormalParameter`, so the un-unwrapped test returned false and the field name was never added to the assigned set. Only required positional `this.field` parameters (which are un-wrapped) were recognized.

### Fix

In `AvoidUnassignedFieldsRule.runWithReporter` (`lib/src/rules/code_quality/code_quality_variables_rules.dart`), the constructor-parameter loop now unwraps `DefaultFormalParameter` to its inner parameter before the type test, and records the field for both `FieldFormalParameter` (`this.x`) and `SuperFormalParameter` (`super.x`). This reuses the unwrap idiom already present in the same file (`_declaredTypeName`) and the `SuperFormalParameter` handling already used in `compile_time_syntax_rules.dart`, `class_constructor_rules.dart`, and `documentation_rules.dart`. `SimpleFormalParameter` and `FunctionTypedFormalParameter` fall through unchanged, so a genuinely unassigned nullable field still lints.

### Tests

`example/lib/code_quality/avoid_unassigned_fields_fixture.dart` gained the six shapes named in the Fixture Gap: named-required, named-optional, optional-positional, and positional-required initializing formals plus a super-formal subclass (all expect no diagnostic), and a genuinely unassigned nullable field that still expects the diagnostic (true-positive regression guard). The rule's existing unit tests are instantiation and rule-name pins; no behavior assertion needed updating.

### Verification note

The scan CLI and full-package build could not be exercised at fix time: unrelated in-progress edits from other workstreams in the same working tree (`flow/exception_rules.dart`, and the `move_variable_outside_iteration` rework in `code_quality/code_quality_variables_rules.dart`) leave the package non-compiling. The fix is isolated, type-checked against the file's existing analyzer imports, and matches idioms already proven elsewhere in the codebase.

---

## Environment

- saropa_lints version: 14.0.3
- Dart SDK version: 3.12.1
- custom_lint version: via custom_lint CLI
- Triggering project/file: `saropa_drift_advisor` — `lib/src/server/mutation_tracker.dart` (`MutationRowSnapshots`)

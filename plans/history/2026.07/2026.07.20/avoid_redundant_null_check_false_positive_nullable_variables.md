# BUG: `avoid_redundant_null_check` — False positive on nullable variables

**Status: Fixed**

Created: 2026-07-20
Rule: `avoid_redundant_null_check`
File: `lib/src/rules/data/type_safety_rules.dart` (line ~1567)
Severity: High — FP on common null-guard pattern forcing widespread `// ignore:` workaround
Rule version: v1

---

## Summary

`avoid_redundant_null_check` fires on `x == null` / `x != null` comparisons where the variable is explicitly typed as nullable (`ContactModel?`, `Widget?`). The rule claims the value is non-nullable when it is demonstrably nullable from its declaration. Likely related to the `avoid_redundant_await` FP on the same lines — if the await-expression's type resolves incorrectly, the variable's inferred type would be `Future<T?>` (non-nullable at the Future level) rather than `T?`.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_redundant_null_check'" lib/src/rules/
# lib/src/rules/data/type_safety_rules.dart:1583:    'avoid_redundant_null_check',
```

**Emitter registration:** `lib/saropa_lints.dart:3068`
**Rule class:** `AvoidRedundantNullCheckRule` — `lib/src/rules/data/type_safety_rules.dart:1567`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `dartAnalysisLSP`

---

## Reproducer

```dart
// Case 1: nullable from await (cascading from avoid_redundant_await FP)
Future<void> example1() async {
  final ContactModel? a = await DatabaseContactIO.dbContactLoadByContactUUID('x');
  final ContactModel? b = await DatabaseContactIO.dbContactLoadByContactUUID('y');
  if (a == null || b == null) {} // LINT on both comparisons — but should NOT lint (FP)
}

// Case 2: nullable from AsyncSnapshot.data
Widget build(BuildContext context, AsyncSnapshot<List<ContactModel>?> snapshot) {
  final Widget? snapWaiting = snapshot.snapLoadingProgress();
  if (snapWaiting != null) return snapWaiting; // LINT — but should NOT lint (FP)
  return const SizedBox();
}

// Case 3: nullable from method returning T?
Future<void> example3(String uuid) async {
  final ContactModel? primary = await DatabaseContactIO.dbContactLoadByContactUUID(uuid);
  if (primary == null) return; // LINT — but should NOT lint (FP)
}
```

**Frequency:** Always — fires on every null check of these nullable variables.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — variables are explicitly `ContactModel?` and `Widget?` (nullable) |
| **Actual** | `[avoid_redundant_null_check] Comparing a non-nullable value to null is redundant...` reported on each null comparison |

---

## AST Context

```
FunctionDeclaration (example1)
  └─ Block
      └─ IfStatement
          └─ BinaryExpression (||)
              └─ BinaryExpression (==)  ← node reported here
                  ├─ SimpleIdentifier (a)
                  │   staticType: ContactModel?  ← nullable, nullabilitySuffix should be .question
                  └─ NullLiteral
```

---

## Root Cause

### Hypothesis A: Cascading from avoid_redundant_await type mis-resolution

The rule at line 1626 checks `type.nullabilitySuffix == NullabilitySuffix.none`. If the `avoid_redundant_await` FP causes the variable to be inferred as `Future<ContactModel?>` instead of `ContactModel?` (because the plugin thinks the await is on a non-Future), then the outer type IS non-nullable (`Future` itself is non-nullable even though its type argument is nullable). This would make the null check appear redundant to the rule.

### Hypothesis B: Independent type-resolution failure on Widget? from extension method

For the `Widget? snapWaiting = snapshot.snapLoadingProgress()` case, the extension method `snapLoadingProgress()` returns `Widget?`. If the plugin's resolver fails to resolve the extension method's return type and falls back to a non-nullable type, the null check would appear redundant.

---

## Resolution

Added a declared-type cross-check in `runWithReporter()`: when `staticType` resolves as non-nullable, the rule now also checks the identifier's element declared type (`LocalVariableElement.type` or `ParameterElement.type`). If the element was declared as nullable (`NullabilitySuffix.question`), the rule skips — trusting the declaration over a potentially misresolved `staticType`.

**Files changed:**
- `lib/src/rules/data/type_safety_rules.dart` — added `_declaredTypeIsNullable()` guard
- `example/lib/type_safety/avoid_redundant_null_check_fixture.dart` — expanded with nullable variable cases

---

## Fixture Gap

The fixture should include:

1. **`x == null` where x is `Type?` from an await expression** — expect NO lint
2. **`x != null` where x is `Widget?` from an extension method** — expect NO lint
3. **`x == null` in an `||` chain with multiple nullable operands** — expect NO lint on any operand

---

## Environment

- saropa_lints version: 14.3.5
- Dart SDK version: 3.12.2
- Triggering project/file: `d:\src\contacts\lib\components\contact_issues\audit_panel_import_review.dart` (line 151), `audit_panel_linked_contacts.dart` (line 90), `audit_panel_job_title_missing_organization.dart` (line 102)

---

## Finish Report (2026-07-20)

### Defect

`AvoidRedundantNullCheckRule` relied solely on `Expression.staticType.nullabilitySuffix` to determine whether a null comparison was redundant. In the custom_lint plugin context, `staticType` can misresolve to non-nullable for variables explicitly declared as `Type?`, particularly when the initializer involves cross-package static method calls or extension methods. This caused false positives on common null-guard patterns (`if (x == null) return;`).

### Fix (initial)

Added `_declaredTypeIsNullable(Expression)` helper in `type_safety_rules.dart`. After `staticType` indicates non-nullable, the rule cross-checks the identifier's element declared type via `LocalVariableElement.type` or `FormalParameterElement.type`. If the declaration carries `NullabilitySuffix.question`, the rule skips the diagnostic.

### Fix (hardening follow-up)

Three additional guards:

1. **`InvalidType` guard** — when the analyzer fails to resolve a type entirely, `staticType` returns `InvalidType` with `nullabilitySuffix == .none`. The rule now skips `InvalidType` alongside the existing `null` guard, preventing false positives from unresolvable cross-package types.

2. **Broadened `_declaredTypeIsNullable` to all element kinds** — replaced the `LocalVariableElement || FormalParameterElement` check with `VariableElement` (the shared base class covering locals, params, fields, and top-level variables) plus `GetterElement` (explicit getter declarations whose `returnType` carries the nullability). This closes the gap for `obj.field == null` and `obj.getter == null` patterns.

3. **Extracted `_resolveElement(Expression)`** — resolves the backing element from `SimpleIdentifier` (bare `x`), `PrefixedIdentifier` (`prefix.x`), and `PropertyAccess` (`obj.x`), so `_declaredTypeIsNullable` works for property access expressions, not just bare identifiers.

### Trade-off

The cross-check suppresses the lint for variables declared nullable even after flow-analysis promotion (e.g., `if (x != null && x == null)` where the second check IS redundant post-promotion). This is an acceptable loss — that pattern is vanishingly rare and the FP cost on common null-guard patterns is far higher.

### Files changed

| File | Change |
|------|--------|
| `lib/src/rules/data/type_safety_rules.dart` | Added `element.dart` import, `InvalidType` guard, `_declaredTypeIsNullable()` with `VariableElement`/`GetterElement` coverage, `_resolveElement()` for `SimpleIdentifier`/`PrefixedIdentifier`/`PropertyAccess` |
| `example/lib/type_safety/avoid_redundant_null_check_fixture.dart` | Expanded: nullable param, local, `!=`, `||` chain, nullable field/getter property access (GOOD), non-nullable param/local (BAD) |
| `CHANGELOG.md` | Entry under `[Unreleased] > Fixed` |
| `bugs/BUG_REPORT_GUIDE.md` | Reference updated to archived path |
| `test/rules/testing/debug_rules_test.dart` | Fixed stale rule count docstring (9 -> 11), fixed indentation on `AvoidUnguardedDebugRule` test |

### Tests

All 35 `type_safety_rules_test.dart` tests pass.

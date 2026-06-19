# BUG: `avoid_throw_objects_without_tostring` — Fires on a class that explicitly overrides `toString()` when thrown via `Error.throwWithStackTrace`

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `avoid_throw_objects_without_tostring`
File: `lib/src/rules/flow/exception_rules.dart` (line ~260)
Severity: False positive — High
Rule version: v6 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule reports a thrown object as lacking a `toString()` override even though the thrown object's class explicitly declares `@override String toString()`. The throw operand is `Error.throwWithStackTrace(error, stack)`, whose static type is `Never`; the rule reads the static type of the call expression (`Never`) instead of the first argument (`BatchApplyStatementError`), so it never finds the declared `toString` and emits a diagnostic.

Expected: no diagnostic — the thrown class overrides `toString()`.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'avoid_throw_objects_without_tostring'" lib/src/rules/
# Result: lib/src/rules/flow/exception_rules.dart:260

# Negative — rule is NOT defined in the triggering downstream project
grep -rn "avoid_throw_objects_without_tostring" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# Result: 0 matches (the rule name appears only in that project's analysis_options.yaml, i.e. it is consumed, not defined)
```

**Emitter registration:** `lib/src/rules/flow/exception_rules.dart:260` (the `LintCode` id)
**Rule class:** `AvoidThrowObjectsWithoutToStringRule` (`lib/src/rules/flow/exception_rules.dart:243`) — registered in `lib/saropa_lints.dart:388` (`AvoidThrowObjectsWithoutToStringRule.new`); enabled in tier `lib/tiers/comprehensive.yaml:185` and listed in `lib/src/tiers.dart:2493`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints custom_lint plugin)

---

## Reproducer

Minimal Dart code that triggers the bug. Source: `saropa_drift_advisor/lib/src/server/edits_batch_handler.dart`.

```dart
final class BatchApplyStatementError implements Exception {
  BatchApplyStatementError({
    required this.index,
    required this.statement,
    required this.cause,
  });

  final int index;
  final String statement;
  final Object cause;

  @override
  String toString() =>
      'Statement #$index failed during batch apply: $cause'; // <-- toString IS overridden
}

void apply(List<String> statements) {
  for (var i = 0; i < statements.length; i++) {
    final rawStmt = statements[i];
    try {
      _run(rawStmt);
    } on Object catch (statementError, statementStack) {
      // LINT avoid_throw_objects_without_tostring reported here —
      // but BatchApplyStatementError HAS a toString() override.
      throw Error.throwWithStackTrace(
        BatchApplyStatementError(
          index: i,
          statement: rawStmt,
          cause: statementError,
        ),
        statementStack,
      );
    }
  }
}

void _run(String _) {}
```

**Frequency:** Reproduces whenever the throw operand is a call to `Error.throwWithStackTrace(obj, stack)` — the diagnostic is independent of whether `obj`'s class overrides `toString()`, because the argument is never inspected (see Root Cause). A plain `throw BatchApplyStatementError(...)` does NOT misfire: there the throw operand's static type resolves to the `InterfaceType` of the class, so the declared `toString` is found at lines 297–304 and the rule returns early. The false positive is specific to throw operands whose static type is `Never` (or otherwise not the intended thrown object's type), of which `Error.throwWithStackTrace(...)` is the canonical case.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `BatchApplyStatementError` declares `@override String toString()` |
| **Actual** | `[avoid_throw_objects_without_tostring]` reported at the `throw Error.throwWithStackTrace(...)` expression |

---

## AST Context

The rule registers `addThrowExpression` and inspects `node.expression`. The throw operand is the `MethodInvocation` for `Error.throwWithStackTrace(...)`, NOT the `BatchApplyStatementError(...)` instance-creation argument.

```
MethodDeclaration (apply)
  └─ Block
      └─ ForStatement
          └─ Block
              └─ TryStatement
                  └─ CatchClause
                      └─ Block
                          └─ ExpressionStatement
                              └─ ThrowExpression                       ← rule reports here (reporter.atNode(node))
                                  └─ MethodInvocation                  ← node.expression — Error.throwWithStackTrace(...)
                                      │   staticType = Never
                                      └─ ArgumentList
                                          ├─ InstanceCreationExpression ← BatchApplyStatementError(...)
                                          │       staticType = BatchApplyStatementError (HAS toString)
                                          └─ SimpleIdentifier (statementStack)
```

The rule evaluates `staticType` of the `MethodInvocation` (`Never`); the type that actually gets thrown is the `staticType` of the first argument (`BatchApplyStatementError`), which the rule never reaches.

---

## Root Cause

The rule's `runWithReporter` (lines 274–308) reads the static type of the throw operand directly and stops there:

```dart
context.addThrowExpression((ThrowExpression node) {
  final Expression expression = node.expression;   // line 280 — the throw operand
  final DartType? type = expression.staticType;    // line 281 — Never for Error.throwWithStackTrace(...)

  if (type == null) return;                         // line 283

  final String typeName = type.getDisplayString();  // line 286 — "Never"

  if (_knownGoodTypesRegex.hasMatch(typeName)) return; // line 289 — "Never" no match
  if (type.isDartCoreString) return;                   // line 294 — false

  if (type is InterfaceType) {                         // line 297 — Never is NOT an InterfaceType
    final bool hasToString = type.element.methods.any(...); // lines 298–303 — skipped
    if (hasToString) return;
  }

  reporter.atNode(node);                               // line 306 — false positive emitted
});
```

### Hypothesis A: rule inspects the throw operand directly and sees `Never` (CONFIRMED — this is the mechanism)

`Error.throwWithStackTrace(error, stack)` returns `Never` (it always throws). The thrown object is its **first argument**, not the call itself. At line 281 the rule reads `node.expression.staticType`, which for this operand is `Never`. `Never`:

- does not match `_knownGoodTypesRegex` (lines 268–272 / 289) — the display string is `"Never"`,
- is not `dart:core` `String` (line 294),
- is **not** an `InterfaceType` (line 297), so the `toString`-override lookup at lines 298–303 is skipped entirely.

Execution falls through to `reporter.atNode(node)` at line 306. The `BatchApplyStatementError` class element — and therefore its declared `toString` — is never examined. This is the fault. The rule is not "failing to find the inherited/declared `toString` on the class element"; it is **never resolving the class element at all**, because it evaluates the wrong expression's static type.

### Hypothesis B: `toString`-override lookup is too strict (secondary, not the trigger here)

Even when an `InterfaceType` IS resolved (the plain `throw obj` path), the override check at lines 298–303 only matches a `toString` whose `enclosingElement == type.element` — i.e. a `toString` declared **directly on the thrown class**. A class that inherits a useful `toString` from a superclass it `extends` (not just `Exception`/`Error`) would still be flagged. This is a separate, narrower gap and is NOT what produces the reproducer here (the reproducer declares `toString` directly), but the fix should make the lookup robust regardless.

---

## Suggested Fix

Two changes in `lib/src/rules/flow/exception_rules.dart`, both in `runWithReporter` (lines 274–308):

1. **Resolve the actual thrown object's type when the operand is `Error.throwWithStackTrace`.** Before reading `staticType` at line 281, detect when `node.expression` is a `MethodInvocation` targeting `Error.throwWithStackTrace` and, if so, evaluate the **first argument's** `staticType` instead of the call's `Never` return. Sketch:

   ```dart
   // Error.throwWithStackTrace(obj, stack) always returns Never, so the
   // throw operand's own static type is Never — useless for this rule.
   // The value actually thrown is the FIRST argument; inspect its type.
   Expression expression = node.expression;
   final MethodInvocation? rethrowCall = expression is MethodInvocation &&
           expression.methodName.name == 'throwWithStackTrace'
       ? expression
       : null;
   if (rethrowCall != null) {
     final args = rethrowCall.argumentList.arguments;
     final first = args.isEmpty ? null : args.first;
     if (first == null) return; // nothing meaningful to check
     expression = first;
   }
   final DartType? type = expression.staticType;
   ```

   Guard against an empty argument list with a nullable-safe accessor (`args.isEmpty ? null : args.first` / `firstOrNull`) — never bare `.first` — and verify the target is the `dart:core` `Error.throwWithStackTrace` (check the method name plus that the realtarget resolves to `Error`), not just any method named `throwWithStackTrace`.

2. **Look up `toString` on the resolved `InterfaceElement` including inherited overrides** (lines 297–303). Replace the direct-declaration-only `methods.any(... enclosingElement == type.element)` heuristic with a lookup that resolves the effective `toString` through the type hierarchy and treats it as "good" when it is declared anywhere other than `Object` (i.e. a real override exists). This removes the secondary gap in Hypothesis B and makes the rule robust for any thrown class with a meaningful `toString`, whether declared directly or inherited from a non-`Object` supertype.

Both line references are in the current `run` body (lines 274–308); the `_knownGoodTypesRegex` at lines 267–272 is unaffected.

---

## Fixture Gap

The fixture at `example*/lib/.../avoid_throw_objects_without_tostring_fixture.dart` should include:

1. **Class with a direct `@override String toString()`, thrown via `throw Error.throwWithStackTrace(obj, stack)`** — expect NO lint (this reproducer).
2. **Same class thrown directly via `throw obj`** — expect NO lint (regression guard; confirms the plain-throw path still resolves the class element).
3. **Class WITHOUT any `toString` override, thrown via `Error.throwWithStackTrace(obj, stack)`** — expect LINT (confirms the new argument-resolution path still detects genuine violations rather than blanket-suppressing `throwWithStackTrace`).
4. **Class that inherits a useful `toString` from a non-`Exception`/`Error` superclass, thrown directly** — expect NO lint (covers Hypothesis B's inherited-override case).

---

## Changes Made

`lib/src/rules/flow/exception_rules.dart` — `AvoidThrowObjectsWithoutToStringRule.runWithReporter`:

1. **Resolve the actual thrown object's type.** A new `_resolveThrownExpression` helper detects when the throw operand is a `MethodInvocation` named `throwWithStackTrace` whose enclosing element is `dart:core`'s `Error` class, and returns the call's **first argument** instead of the `Never`-typed call. The class check (`InterfaceElement` named `Error` in library `dart.core`) prevents suppressing an unrelated user method that happens to be named `throwWithStackTrace`. An empty argument list falls back to the original operand (nullable-safe `args.isEmpty ? operand : args.first`).

2. **Robust `toString` lookup including inherited overrides.** A new `_hasUsefulToString` helper walks the thrown type plus `allSupertypes`, skips `Object`, and treats the class as "good" when any non-`Object` class in the hierarchy declares `toString()` — replacing the prior direct-declaration-only check that missed overrides inherited from a real superclass (Hypothesis B).

---

## Tests Added

- `test/rules/flow/flow_fp_test.dart` — new group `avoid_throw_objects_without_tostring — throwWithStackTrace operand`, run against a FULLY RESOLVED unit via the resolved-rule harness (the scan CLI uses `parseString`, so `staticType` is null and cannot exercise this rule). Five cases covering the bug's Fixture Gap:
  1. class with direct `toString()` thrown via `throwWithStackTrace` → no lint (the reproducer)
  2. same class thrown directly → no lint (plain-throw regression guard)
  3. class inheriting `toString()` from a non-Exception base → no lint (Hypothesis B)
  4. class without `toString()` via `throwWithStackTrace` → lint (genuine violation still caught)
  5. class without `toString()` thrown directly → lint (baseline preserved)
- `example/lib/exception/avoid_throw_objects_without_tostring_fixture.dart` — added the same scenarios as documentation fixtures.

All 12 tests in the file pass; `dart analyze lib/src/rules/flow/exception_rules.dart` reports no issues.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 14.0.3
- Dart SDK version: 3.12.1
- custom_lint version: via CLI (`dart run custom_lint`)
- Triggering project/file: `saropa_drift_advisor` — `lib/src/server/edits_batch_handler.dart` (throw of `BatchApplyStatementError` via `Error.throwWithStackTrace`)

---

## Finish Report (2026-06-19)

### Defect

`avoid_throw_objects_without_tostring` read `node.expression.staticType` of the throw operand and stopped there. For `throw Error.throwWithStackTrace(obj, stack)` the operand is the call expression, whose static type is `Never` (the function always throws). `Never` is not an `InterfaceType`, so the rule never resolved the thrown class element and never found its `toString()` override — it reported the throw unconditionally. The actually-thrown value is the call's first argument, which the rule never inspected. A secondary gap: even on the plain-throw path, the override check only accepted a `toString()` declared directly on the thrown class, missing one inherited from a non-`Object` superclass.

### Resolution

`runWithReporter` in `lib/src/rules/flow/exception_rules.dart` gained two static helpers:

- `_resolveThrownExpression(Expression)` — when the operand is a `MethodInvocation` named `throwWithStackTrace` whose enclosing element is an `InterfaceElement` named `Error` in library `dart.core`, it returns the call's first argument so the rule inspects the genuinely-thrown object's type. The `dart.core` `Error` guard prevents suppressing an unrelated user method sharing the name. An empty argument list falls back to the original operand via a nullable-safe `args.isEmpty ? operand : args.first`.
- `_hasUsefulToString(InterfaceType)` — walks the thrown type plus `allSupertypes`, skips `Object`, and accepts the class when any non-`Object` class in the hierarchy declares `toString()`, covering both direct and inherited overrides.

The rule version tag was bumped `{v6}` → `{v7}` and the dartdoc header updated to `Rule version: v7`.

### Verification

The scan CLI uses `parseString` (unresolved AST), so `staticType` is null there and this type-dependent rule cannot be exercised by it. Verification used the resolved-rule harness (`test/support/resolved_rule_harness.dart`), which analyzes a fixture with full type/element resolution. Five cases were added to `test/rules/flow/flow_fp_test.dart`: a `toString`-bearing class thrown via `throwWithStackTrace` (no lint), the same class thrown directly (no lint), a class inheriting `toString()` from a base (no lint), a class without `toString()` thrown via `throwWithStackTrace` (lint), and a class without `toString()` thrown directly (lint). All 12 tests in the file pass. `dart analyze` on the rule file reports no issues; the existing exception-rule instantiation and fixture tests pass.

# BUG: `function_always_returns_null` — false positive on override of nullable getter from parent class

**Status: Open**

Created: 2026-05-31
Rule: `function_always_returns_null`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~663, body check ~712)
Severity: False positive
Rule version: v6

---

## Summary

The rule fires on `@override` getter declarations where the parent class
declares the getter with a nullable return type AND returning `null` is the
documented API contract for "absence of value". The override is structurally
forced to use the parent's signature (return type cannot widen), and returning
anything other than `null` would lie about the absence. The rule treats this
as "function returns null on every code path" and recommends changing the
return type to `void` — but the return type cannot be changed without breaking
the override.

The textbook example, and the case that surfaced this report, is overriding
`ModalRoute.barrierColor` / `ModalRoute.barrierLabel` to opt out of the modal
barrier on a no-barrier route. Flutter's own docs say "return null to indicate
no barrier".

---

## Attribution Evidence

```bash
# Positive — rule IS defined in saropa_lints
grep -rn "'function_always_returns_null'" D:/src/saropa_lints/lib/src/rules/
# D:/src/saropa_lints/lib/src/rules/code_quality/code_quality_variables_rules.dart:663:    'function_always_returns_null',

# Negative — rule is NOT in saropa_drift_advisor
grep -rn "'function_always_returns_null'" D:/src/saropa_drift_advisor/lib/src D:/src/saropa_drift_advisor/extension/src
# (zero matches)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:663`
**Rule class:** `FunctionAlwaysReturnsNullRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (custom_lint)

---

## Reproducer

The smallest reproducer is a no-barrier `PopupRoute` subclass — Flutter's
documented pattern for a route that participates in the navigator stack
without painting / catching a modal barrier:

```dart
import 'package:flutter/widgets.dart';

class _NoBarrierRoute extends PopupRoute<void> {
  // expect_lint: function_always_returns_null  (FALSE POSITIVE)
  @override
  Color? get barrierColor => null;   // returning null IS the API contract
                                     // for "this route has no barrier"

  @override
  bool get barrierDismissible => false;

  // expect_lint: function_always_returns_null  (FALSE POSITIVE)
  @override
  String? get barrierLabel => null;  // a11y label only meaningful for
                                     // visible barriers; null is correct
                                     // when barrierColor is also null

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox.shrink();
}
```

**Frequency:** Always — fires on every `@override Color? get barrierColor =>
null;` and every analogous nullable-getter override that returns null.

**Downstream sites this surfaced on (real codebase):**

- `saropa_contacts/lib/components/primitive/menu/menu_utils.dart` —
  `_MenuBackdropRoute` class, lines 118 and 124. Identical pattern:
  no-barrier popup route used as a backdrop scrim layer behind a popup
  menu. Both lines silenced with `// ignore: function_always_returns_null`
  pointing at this bug.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. Overriding a nullable getter to return `null` is the parent type's documented contract — the return type is not the override's to change, and returning anything else would lie about the contract. |
| **Actual** | `[function_always_returns_null] Function returns null on every code path, making the return type effectively void. Callers that check or use the return value are performing dead logic, and the nullable return type misleads developers into thinking the function can return meaningful data. {v6}` |

The correction message recommends "Change the return type to void" — which is
impossible without breaking the override (the analyzer would then report
`invalid_override` because the subclass return type doesn't match the parent's
`Color?` / `String?`).

---

## AST Context

```
ClassDeclaration (_NoBarrierRoute)
  ├─ extends PopupRoute<void>
  └─ MethodDeclaration (isGetter == true, name='barrierColor')
      ├─ metadata: [Annotation('override')]
      ├─ returnType: NamedType('Color', nullable: true)
      └─ ExpressionFunctionBody
          └─ NullLiteral                                ← rule fires here
```

The rule's `_checkFunctionBody` hits the `ExpressionFunctionBody` +
`NullLiteral` branch (`code_quality_variables_rules.dart:712-715`) and reports
on `nameToken`. The presence of the `@override` annotation and the parent's
nullable return type are not checked.

---

## Root Cause

### Hypothesis A: `@override` is not consulted (most likely)

`_checkFunctionBody` in `code_quality_variables_rules.dart` inspects the body
and the return type token, but never looks at `node.metadata` to detect
`@override`, and never resolves the overridden member to check whether the
parent declares the getter as nullable.

The check at line 712 fires on **any** expression-body that is `NullLiteral`
when the return type is nullable, regardless of whether the method overrides
a parent declaration that contractually says "null means absent".

### Hypothesis B: Generator-style skip would not help here

The existing skip lists (generators, void, `Future<void>`, `Stream` /
`Iterable` return-type belt-and-suspenders) don't apply to getters. Adding
generator branches won't fix this case — the gating axis is "is this an
`@override` of a parent nullable getter", not "is this a generator".

---

## Suggested Fix

In `_checkFunctionBody`, add an early-exit clause:

```dart
// Skip @override declarations where the parent declares the same name as
// returning a nullable type. The parent's nullable return type IS the
// contract — returning null is honoring it, not a code smell. Common
// example: `@override Color? get barrierColor => null;` overriding
// `ModalRoute.barrierColor` to opt out of the modal barrier.
//
// NOTE: a syntactic check for the `@override` annotation is sufficient and
// avoids a full element-model lookup. False positives from omitted
// `@override` annotations would re-fire on the same null-returning
// override (rare; users mark @override).
if (_hasOverrideAnnotation(nameToken.parent)) return;
```

Where `_hasOverrideAnnotation` walks the enclosing `MethodDeclaration` /
`FunctionDeclaration` and checks `metadata.any((a) => a.name.name == 'override')`.

Alternative (more precise but heavier): use the resolved
`ExecutableElement.declaration.enclosingElement` to look up the overridden
member, and check whether its return type is nullable. If yes, skip.

The annotation-based check is the cheaper option and would close ~all
real-world hits of this pattern.

---

## Fixture Gap

The fixture at `example/lib/code_quality/function_always_returns_null_fixture.dart`
should include:

1. **Override of nullable getter returning null** — expect NO lint
   ```dart
   abstract class _Parent {
     Color? get tint;
     String? get label;
   }
   class _Child extends _Parent {
     @override
     Color? get tint => null;   // honors parent contract; no lint
     @override
     String? get label => null; // honors parent contract; no lint
   }
   ```

2. **Override of nullable method returning null** — expect NO lint
   ```dart
   abstract class _ParentMethod {
     Color? compute();
   }
   class _ChildMethod extends _ParentMethod {
     @override
     Color? compute() => null;   // honors parent contract; no lint
   }
   ```

3. **Negative guard: same shape without `@override`** — expect LINT
   ```dart
   Color? unannotatedGetter() => null;  // not an override; current rule
                                        // behavior preserved
   ```

4. **Negative guard: `@override` of NON-nullable parent** — expect LINT
   when the parent's return type is non-nullable but the child somehow
   declares a nullable return (this case shouldn't compile at all — the
   override is invalid — so it's effectively unreachable, but the fixture
   should pin the boundary).

---

## Changes Made

(Filled in when a fix is written.)

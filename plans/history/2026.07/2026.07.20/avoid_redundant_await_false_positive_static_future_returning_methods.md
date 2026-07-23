# BUG: `avoid_redundant_await` — False positive on static methods returning Future

**Status: Fixed**

Created: 2026-07-20
Rule: `avoid_redundant_await`
File: `lib/src/rules/core/async_rules.dart` (line ~5200)
Severity: High — FP on common pattern forcing widespread `// ignore:` workaround
Rule version: v3 | Since: v5.1.0

---

## Summary

`avoid_redundant_await` fires on `await` expressions where the awaited method is a `static Future<T>` method on a Drift I/O class. The methods unambiguously return `Future<ContactModel?>`, `Future<List<ContactModel>>`, `Future<bool>`, and `Future<void>`, yet the rule reports "Awaiting a non-Future expression is redundant." The `_staticTypeIsAwaitable` check at line ~5245 is not recognizing the return type as a Future in these call sites.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_redundant_await'" lib/src/rules/
# lib/src/rules/core/async_rules.dart:5216:    'avoid_redundant_await',
```

**Emitter registration:** `lib/saropa_lints.dart:3063`
**Rule class:** `AvoidRedundantAwaitRule` — `lib/src/rules/core/async_rules.dart:5200`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `dartAnalysisLSP`

---

## Reproducer

```dart
class DatabaseContactIO {
  static Future<ContactModel?> dbContactLoadByContactUUID(String uuid) async {
    return null;
  }
  static Future<List<ContactModel>> dbContactLoadSecondariesOfPrimary(String uuid) async {
    return [];
  }
  static Future<bool> dbContactSetPrimary({required String secondaryUUID, required String? primaryUUID}) async {
    return true;
  }
}

class ContactMatchExclusions {
  static Future<void> exclude(String a, String b) async {}
}

class ContactMatchConfirmations {
  static Future<void> unconfirm(String a, String b) async {}
}

Future<void> example() async {
  final ContactModel? a = await DatabaseContactIO.dbContactLoadByContactUUID('x'); // LINT — but should NOT lint (FP)
  final List<ContactModel> secs = await DatabaseContactIO.dbContactLoadSecondariesOfPrimary('x'); // LINT — but should NOT lint (FP)
  final bool ok = await DatabaseContactIO.dbContactSetPrimary(secondaryUUID: 'a', primaryUUID: null); // LINT — but should NOT lint (FP)
  await ContactMatchExclusions.exclude('a', 'b'); // LINT — but should NOT lint (FP)
  await ContactMatchConfirmations.unconfirm('a', 'b'); // LINT — but should NOT lint (FP)
}
```

**Frequency:** Always — fires on every `await` of these static Future-returning methods in `contact_issues/` files.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the awaited expressions return `Future<T>` |
| **Actual** | `[avoid_redundant_await] Awaiting a non-Future expression is redundant...` reported on each `await` |

---

## AST Context

```
FunctionDeclaration (example)
  └─ Block
      └─ VariableDeclarationStatement
          └─ VariableDeclaration (a)
              └─ AwaitExpression  ← node reported here
                  └─ MethodInvocation (DatabaseContactIO.dbContactLoadByContactUUID)
                      staticType: Future<ContactModel?>  ← should pass _staticTypeIsAwaitable
```

---

## Root Cause

### Hypothesis A: staticType resolves to null or a non-Future type in the plugin context

The rule at line 5232 reads `node.expression.staticType`. If the analyzer plugin's type resolution fails for cross-package static method calls (e.g., the Drift I/O class lives in a different part of the package and the plugin's resolver doesn't fully resolve it), `staticType` could return `null` — but the rule returns early on null (line 5233). If instead it resolves to the raw method element type (a `FunctionType`) rather than the invocation's return type, `_staticTypeIsAwaitable` would not match since `FunctionType` is not `InterfaceType` and doesn't satisfy `isDartAsyncFuture`.

### Hypothesis B: MethodInvocation on a static target resolves differently

When the expression is `DatabaseContactIO.dbContactLoadByContactUUID(pair.$1)`, the `staticType` of the `MethodInvocation` should be the return type (`Future<ContactModel?>`). But if the resolver returns the method's own type signature as a `FunctionType` rather than evaluating the invocation's result type, the `isDartAsyncFuture` check would fail.

---

## Suggested Fix

In `runWithReporter` (line ~5231), after getting `type`, add a guard for `FunctionType` — if the expression is a `MethodInvocation` whose `staticInvokeType` resolves to a `FunctionType`, use `functionType.returnType` instead of `node.expression.staticType` for the awaitable check. Alternatively, investigate why the resolver provides a non-Future `staticType` for these particular invocations and fix the type-query path.

---

## Fixture Gap

The fixture should include:

1. **`await` on a static method returning `Future<T?>`** — expect NO lint
2. **`await` on a static method returning `Future<List<T>>`** — expect NO lint
3. **`await` on a static method returning `Future<bool>`** — expect NO lint
4. **`await` on a static method returning `Future<void>`** — expect NO lint
5. **`await` on a static method from a class with a private constructor** — expect NO lint

---

## Environment

- saropa_lints version: 14.3.5
- Dart SDK version: 3.12.2
- Triggering project/file: `d:\src\contacts\lib\components\contact_issues\audit_panel_import_review.dart`, `audit_panel_linked_contacts.dart`, `audit_panel_name_duplicate.dart`

---

## Finish Report (2026-07-20)

### Defect

`AvoidRedundantAwaitRule` reported false positives on `await` expressions targeting static methods that return `Future<T>`. The rule relied solely on `node.expression.staticType` to determine awaitability, which in cross-file/cross-package analyzer-plugin resolution contexts can fail to resolve as `Future<T>` — returning `FunctionType`, `InvalidType`, or another non-`InterfaceType` instead of the invocation's return type.

### Fix

Added a fallback in `runWithReporter` (after the primary `_staticTypeIsAwaitable(type)` check) that inspects `staticInvokeType` on `MethodInvocation` and `FunctionExpressionInvocation` nodes. When `staticInvokeType` is a `FunctionType`, the rule checks whether `returnType` is awaitable before reporting. This catches the case where the expression-level `staticType` doesn't resolve but the method signature's return type does.

### Files Changed

| File | Change |
|------|--------|
| `lib/src/rules/core/async_rules.dart` | Added `staticInvokeType.returnType` fallback (lines 5247-5260) |
| `example/lib/async/avoid_redundant_await_fixture.dart` | Added `_StaticFutureIO` class with `Future<T?>`, `Future<List<T>>`, `Future<bool>`, `Future<void>` static methods |
| `test/rules/core/async_rules_test.dart` | Added fixture verification test for static method regression |
| `CHANGELOG.md` | Added fix entry under `[Unreleased]` |
| `bugs/BUG_REPORT_GUIDE.md` | Updated reference to archived status |

### Limitations

The fixture exercises the code pattern but cannot reproduce the actual cross-file resolution divergence between `staticType` and `staticInvokeType.returnType` — that requires the native analyzer-plugin's incremental resolution context, which single-file fixture compilation units do not exhibit. The fallback is defensive code proven necessary by production observation in the `contacts` project.

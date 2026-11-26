# BUG: `require_firebase_error_handling` — fires in a private helper whose every call is inside try-catch

**Status: Fixed**

Created: 2026-11-26
Rule: `require_firebase_error_handling`
File: `lib/src/rules/packages/firebase_rules.dart` (line ~2506)
Severity: False positive
Rule version: v2 | Since: v4.1.5 | Updated: v4.13.0

---

## Summary

A private wrapper around one Firebase call is reported although each call to it (here through a private-bound function field used as a test seam) is inside a `try`.

---

## Attribution Evidence

```bash
grep -rn "'require_firebase_error_handling'" lib/src/rules/
# lib/src/rules/packages/firebase_rules.dart:2482:    'require_firebase_error_handling',
```

**Emitter registration:** `lib/src/rules/packages/firebase_rules.dart:2482`
**Rule class:** `RequireFirebaseErrorHandlingRule` — registered in `lib/saropa_lints.dart:2136`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
class Policy {
  @visibleForTesting
  static Future<void> Function({required bool isEnabled}) setAutoInit = _setAutoInit;

  static Future<void> onDisconnect() async {
    try {
      await setAutoInit(isEnabled: false);
    } on Object catch (e) {
      print(e);
    }
  }

  static Future<void> _setAutoInit({required bool isEnabled}) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(isEnabled); // LINT — but should NOT lint
  }
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[require_firebase_error_handling]` reported on the line marked LINT |

---

## AST Context

```
MethodDeclaration (_setAutoInit)
  └─ Block
      └─ ExpressionStatement
          └─ AwaitExpression  ← reported
              └─ MethodInvocation (setAutoInitEnabled)
```

---

## Root Cause

`_isInsideTryCatch` (lines ~2535-2549) walks parents and stops at the first `FunctionBody`. Error handling in the callers of a private helper is never considered.

---

## Suggested Fix

For a private function or method, resolve references in the same library (direct calls and tear-offs assigned to a field). Skip the report when every invocation is inside a `try` with a catch clause. Keep the report when any reference cannot be traced.

---

## Fixture Gap

1. Private helper, all callers in try — expect NO lint
2. Private helper with one unguarded caller — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/packages/firebase_rules.dart`, rule version v3): a Firebase call in a private or local async helper is not reported when every reference in the library is an awaited call inside a try with a catch clause, directly or through a private or `@visibleForTesting` function field holding the tear-off.

**Reproducer correction:** the original reproducer used a public, unannotated seam field. Any other library can invoke it without a try, so it is still reported by design. The reproducer above now carries `@visibleForTesting`.

**Review fix:** a file that is itself a `part of` another library was accepted although callers can live elsewhere; it now keeps the report, with a regression case.

**Limits:** references are matched by name across the file, which can only withhold the exemption. A `@visibleForTesting` field can be called unguarded from a test.

Tests: `dart test test/rules/packages/require_firebase_error_handling_guarded_helper_test.dart test/rules/packages/firebase_rules_test.dart` - passed.

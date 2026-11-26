# BUG: `require_notification_for_long_tasks` — method name `syncAll...` alone marks a short local refresh as long-running

**Status: Fixed**

Created: 2026-11-26
Rule: `require_notification_for_long_tasks`
File: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` (line ~2534)
Severity: False positive
Rule version: v2 | Since: v2.4.0 | Updated: v4.13.0

---

## Summary

Any invocation whose name contains `syncAll` at camelCase boundaries is reported, including a short local widget refresh that needs no progress notification.

---

## Attribution Evidence

```bash
grep -rn "'require_notification_for_long_tasks'" lib/src/rules/
# lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:2494:    'require_notification_for_long_tasks',
```

**Emitter registration:** `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:2494`
**Rule class:** `RequireNotificationForLongTasksRule` — registered in `lib/saropa_lints.dart:2025`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
Future<void> syncWidgetA() async {}
Future<void> syncWidgetB() async {}

/// Rewrites two home screen widgets from local data.
Future<void> syncAllWidgets() async {
  await syncWidgetA();
  await syncWidgetB();
}

Future<void> onLocaleChanged() async {
  await syncAllWidgets(); // LINT — but should NOT lint
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[require_notification_for_long_tasks]` reported on the line marked LINT |

---

## AST Context

```
MethodDeclaration / FunctionDeclaration
  └─ Block
      └─ AwaitExpression
          └─ MethodInvocation (syncAllWidgets)  ← reported
```

---

## Root Cause

`runWithReporter` (lines ~2546-2555) reports on `longOperationMethodNameMatchesPattern(methodName, pattern)` alone. `syncAll` matches `syncAllWidgets` because `W` is a camelCase boundary. Nothing inspects the target, the body or any transfer/loop evidence. The only exemption is a whole-file substring scan for progress signals.

---

## Suggested Fix

Require evidence of long work besides the name (for `syncAll`/`processAll`: network or file transfer, or a loop over a collection, in a resolvable callee), or lower the generic `syncAll` pattern to exact-name matches.

---

## Fixture Gap

1. `syncAllWidgets()` over local writes — expect NO lint
2. `uploadLargeFile()` with no progress — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/platforms/ios_platform_lifecycle_rules.dart`, rule version v3): a call matched only by a generic name (`syncAll`, `processAll`, `exportAll`, `importAll`) is skipped when the callee is declared in the same file and its body, followed through same-file callees, provably does only short work. `doc/guides/apple_platform_rules.md` was updated.

**Limits:**
- Cross-file: a callee declared in another file cannot be inspected, so the call is still reported, even when it is short. A same-file callee that itself calls into another file is also still reported.
- The proof needs resolved elements; the unresolved `scan` reports as before (the boundary-OK fixture's new case is reported there).
- Getters, setters, operators and constructors (hardening pass): a getter or setter must be a plain field or variable access that no getter can override, or a same-file accessor whose body is itself short. Any user-defined operator (`+`, `[]`, `[]=`, unary, compound) must be a same-file member that cannot be overridden and has a short body. Public operators always fail this. Only dart:core / dart:async / dart:collection / dart:convert / dart:math (and Flutter foundation) constructors, not `Stream` ones, count as short. A `dynamic` or unresolved receiver, a dot-shorthand call to a non-SDK member, calling a function-typed field, returning or wrapping a stored future (`=> _pending`, `Future.value(_pending)`) and public instance fields all count as long.
- A private member is short only when the library has no `part` files and no other class, mixin or enum in the file declares a member of that name or a `noSuchMethod`. Before this, a same-file subclass override was not seen.
- An implicit `toString()` call (string interpolation, `print(obj)`) is not inspected.
- The BAD example fixture's header no longer names the rule's skip signals. The rule now reports all three `expect_lint` calls there, and a unit test runs the fixture through the resolved harness to check this.

Tests: `dart test test/rules/platforms/require_notification_for_long_tasks_behavior_test.dart test/rules/ui/require_notification_for_long_tasks_fixture_test.dart test/rules/platforms/ios_rules_test.dart` - passed (34 + 181 after the hardening pass).

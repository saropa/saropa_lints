# BUG: `avoid_uncaught_future_errors` — flags `Map<K, Future<V>>.remove(key)` as if it started a fire-and-forget Future

**Status: Open**

Created: 2026-10-29
Rule: `avoid_uncaught_future_errors`
File: `lib/src/rules/flow/error_handling_rules.dart` (class ~923, code ~942)
Severity: False positive
Rule version: v5 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule reports an expression statement whose static type is a `Future` (or any subtype). `Map<K, Future<V>>.remove(key)` has the static type `Future<V>?` because it returns the stored value. The rule reads that as "a Future was created and dropped". No Future is created. The same pattern is reported by three sibling rules (`avoid_uncaught_future_errors`, `avoid_unawaited_future`, `avoid_async_call_in_sync_function`); each has its own report with the matching code path.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_uncaught_future_errors'" lib/src/rules/
# lib/src/rules/flow/error_handling_rules.dart:942:    'avoid_uncaught_future_errors',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/flow/error_handling_rules.dart:942`; registered at `lib/saropa_lints.dart:1546` (`AvoidUncaughtFutureErrorsRule.new`)
**Rule class:** `AvoidUncaughtFutureErrorsRule` (`lib/src/rules/flow/error_handling_rules.dart:923`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Compiles standalone (plain Dart, no packages).

```dart
final Map<String, Future<int?>> _inFlight = <String, Future<int?>>{};

Future<int?> save(String key, Future<int?> Function() run) {
  final Future<int?> queued = run();
  _inFlight[key] = queued;
  return queued.whenComplete(() {
    // Only this call's own registration is safe to clear.
    if (identical(_inFlight[key], queued)) {
      _inFlight.remove(key); // LINT — but should NOT lint (false positive)
    }
  });
}

void main() => save('a', () async => 1);
```

Real source: `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/user_preference_save_drift_io.dart:35-66`
(`static final Map<UserPreferenceType, Future<int?>> _inFlightSaves`, and `_inFlightSaves.remove(type);` at line 64, col 9-36, inside the `whenComplete` callback of `dbUserPreferenceSaveByType`).

**Frequency:** Always, for any `Map<K, Future<V>>` / `Map<K, Future<V>?>` `.remove(...)` used as a statement.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. |
| **Actual** | `[avoid_uncaught_future_errors] Fire-and-forget Future called without error handling. Any exception thrown by this Future is silently lost or crashes the app via the global error handler. Without .catchError(), try-catch, or .ignore(), async failures become invisible in production and extremely difficult to diagnose from crash logs. {v5}` at `user_preference_save_drift_io.dart` 64:9-64:36 |

---

## AST Context

```
ClassDeclaration (DatabaseUserPreferenceSaveDriftIO)
  └─ MethodDeclaration (static dbUserPreferenceSaveByType)   // returns Future<int?>, NOT async
      └─ BlockFunctionBody → Block
          └─ ReturnStatement
              └─ MethodInvocation (queued.whenComplete)
                  └─ ArgumentList
                      └─ FunctionExpression (() { ... })   // synchronous closure
                          └─ BlockFunctionBody → Block
                              └─ IfStatement (identical(_inFlightSaves[type], queued))
                                  └─ Block
                                      └─ ExpressionStatement
                                          └─ MethodInvocation (_inFlightSaves.remove(type))  ← reported
                                              staticType: Future<int?>?   // Map<K, Future<int?>>.remove -> V?
```

---

## Root Cause

`error_handling_rules.dart` `AvoidUncaughtFutureErrorsRule.runWithReporter` (~1005-1040):

```dart
context.addExpressionStatement((ExpressionStatement node) {
  final Expression expression = node.expression;
  ...
  if (expression is MethodInvocation) {
    final type = expression.staticType;
    if (type != null && type.isDartAsyncFuture) {          // true for Future<int?>? (nullability ignored)
      if (_isInsideDisposeMethod(node)) return;
      if (_isInTryBlock(node)) return;
      final String methodName = expression.methodName.name;
      if (_safeFireAndForgetMethods.contains(methodName)) return;   // 'remove' is not listed
      if (functionsWithTryCatch.contains(methodName)) return;
      if (!_hasErrorHandling(expression)) reporter.atNode(expression);
    }
  }
});
```

The only test is `staticType.isDartAsyncFuture`. `DartType.isDartAsyncFuture` ignores the nullability suffix, so `Future<int?>?` matches. The method name `remove` is not in `_safeFireAndForgetMethods`. The rule never asks whether the call creates the Future (an `async` function, a `Future` constructor or factory, a `.then`/`.catchError` chain) or merely returns an existing one.

---

## Why the code is correct

`Map<K, V>.remove(key)` is a synchronous collection method. It returns the value that was stored (here `Future<int?>?`). It does not start, create or schedule any asynchronous work. The Future it returns is the one that was already created and awaited elsewhere (`return queued.whenComplete(...)`). Dropping the removed value is the normal use of `Map.remove`, the same as `list.remove(x)`. There is no lost error: the Future stored in the map is the one the method returns to its caller.

---

## Affected Locations (contacts app)

Line numbers as reported by the diagnostics:

| File | Line:col |
|---|---|
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/user_preference_save_drift_io.dart` | 64:9-64:36 |

(The same statement is flagged by all three sibling rules.)

---

## Suggested Fix

In the `MethodInvocation` branch, skip invocations whose target type is a collection: `target.staticType` is an `InterfaceType` whose element is `Map`, `List`, `Set` or `Queue` (dart:core / dart:collection), when the method is `remove`, `removeAt`, `removeLast`, `removeFirst`, `putIfAbsent`, `update` or an index read. These return stored values. Alternatively require that the method's declaring element is an `async` function or returns `Future` in its declared return type (not `V?` substituted from a type argument).

---

## Fixture Gap

1. `_futureMap.remove(key);` where `_futureMap` is `Map<String, Future<int?>>` — expect NO lint (new)
2. `_futureList.removeLast();` where the list holds `Future`s — expect NO lint (new)
3. `fetchData();` where `Future<void> fetchData() async {}` — expect LINT (unchanged)
4. `_futureMap[key]?.then((v) {});` — expect LINT or NO lint per existing `.then` handling (unchanged)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations

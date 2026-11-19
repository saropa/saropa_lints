# BUG: `avoid_unawaited_future` — flags `Map<K, Future<V>>.remove(key)` as if it started a fire-and-forget Future

**Status: Open**

Created: 2026-10-29
Rule: `avoid_unawaited_future`
File: `lib/src/rules/core/async_rules.dart` (class ~3653, code ~3678)
Severity: False positive
Rule version: v3 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule reports an expression statement whose static type is a `Future` (or any subtype). `Map<K, Future<V>>.remove(key)` has the static type `Future<V>?` because it returns the stored value. The rule reads that as "a Future was created and dropped". No Future is created. The same pattern is reported by three sibling rules (`avoid_uncaught_future_errors`, `avoid_unawaited_future`, `avoid_async_call_in_sync_function`); each has its own report with the matching code path.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_unawaited_future'" lib/src/rules/
# lib/src/rules/core/async_rules.dart:3678:    'avoid_unawaited_future',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/core/async_rules.dart:3678`; registered at `lib/saropa_lints.dart:1808` (`AvoidUnawaitedFutureRule.new`)
**Rule class:** `AvoidUnawaitedFutureRule` (`lib/src/rules/core/async_rules.dart:3653`)
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
| **Actual** | `[avoid_unawaited_future] Not awaiting a Future means any errors or exceptions it throws may be silently lost, leading to missed bugs and unreliable app behavior. This is especially risky in production code where error reporting is critical. {v3}` at `user_preference_save_drift_io.dart` 64:9-64:36 |

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

`async_rules.dart` `AvoidUnawaitedFutureRule.runWithReporter` (~3687-3715):

```dart
context.addExpressionStatement((ExpressionStatement node) {
  final Expression expr = node.expression;
  if (expr is MethodInvocation && expr.methodName.name == 'unawaited') return;
  if (expr is MethodInvocation) {
    final DartType? returnType = expr.staticType;
    if (returnType != null && _staticTypeIsFuture(returnType)) {   // async_rules.dart:5505
      if (_isSafeFireAndForget(expr, node)) return;
      reporter.atNode(expr);
    }
  }
  ...
});
```

`_staticTypeIsFuture` (`async_rules.dart:5505-5509`) is `type.isDartAsyncFuture || allSupertypes.any(isDartAsyncFuture)`. It is true for `Future<int?>?`. `_isSafeFireAndForget` only exempts subscription `cancel`, `StreamController.close`, sync void cleanup `close/cancel`, and `.catchError/.ignore` chains. `Map.remove` is none of those. The rule never checks whether the invocation creates a Future.

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

In the `MethodInvocation` branch of `runWithReporter`, return early when `expr.realTarget?.staticType` is a `Map`, `List`, `Set` or `Queue` and `expr.methodName.name` is one of the value-returning mutators (`remove`, `removeAt`, `removeLast`, `removeFirst`, `putIfAbsent`, `update`). Put the check inside `_isSafeFireAndForget` so the other callers share it.

---

## Fixture Gap

1. `_futureMap.remove(key);` with `Map<String, Future<int?>>` — expect NO lint (new)
2. `_futureList.removeLast();` with `List<Future<void>>` — expect NO lint (new)
3. `someAsync();` — expect LINT (unchanged)
4. `_sub.cancel();` in `dispose()` — expect NO lint (unchanged)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations

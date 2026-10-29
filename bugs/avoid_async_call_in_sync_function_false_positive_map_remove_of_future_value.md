# BUG: `avoid_async_call_in_sync_function` — flags `Map<K, Future<V>>.remove(key)` as if it started a fire-and-forget Future

**Status: Open**

Created: 2026-10-29
Rule: `avoid_async_call_in_sync_function`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (class ~2340, code ~2360)
Severity: False positive
Rule version: v5 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule reports an expression statement whose static type is a `Future` (or any subtype). `Map<K, Future<V>>.remove(key)` has the static type `Future<V>?` because it returns the stored value. The rule reads that as "a Future was created and dropped". No Future is created. The same pattern is reported by three sibling rules (`avoid_uncaught_future_errors`, `avoid_unawaited_future`, `avoid_async_call_in_sync_function`); each has its own report with the matching code path.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_async_call_in_sync_function'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:2360:    'avoid_async_call_in_sync_function',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:2360`; registered at `lib/saropa_lints.dart:655` (`AvoidAsyncCallInSyncFunctionRule.new`)
**Rule class:** `AvoidAsyncCallInSyncFunctionRule` (`lib/src/rules/code_quality/code_quality_avoid_rules.dart:2340`)
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
| **Actual** | `[avoid_async_call_in_sync_function] Async function called inside a synchronous function without handling the returned Future. The Future is silently discarded, so any errors thrown by the async operation are swallowed and any result is lost, making failures invisible. {v5}` at `user_preference_save_drift_io.dart` 64:9-64:36 |

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

`code_quality_avoid_rules.dart` `AvoidAsyncCallInSyncFunctionRule._shouldReport` (~2395-2440):

```dart
final DartType? returnType = node.staticType;
if (returnType == null) return false;
final String typeName = returnType.getDisplayString();
if (!typeName.startsWith('Future')) return false;              // 'Future<int?>?' passes
final FunctionBody? body = _findEnclosingFunctionBody(node);
if (body == null || body.isAsynchronous) return false;         // the whenComplete closure is sync
if (_isCleanupInLifecycle(node, body)) return false;
if (_isCloseInVoidCallback(node)) return false;
...
return parent is ExpressionStatement;                          // <-- true: bare statement
```

The return type is detected by the display string prefix `Future`, which also matches `Future<int?>?` produced by `Map<K, Future<int?>>.remove`. The enclosing body is the synchronous callback passed to `whenComplete`. The parent is an `ExpressionStatement`, so the call is reported. The rule never checks that the call is to an async function.

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

In `_shouldReport`, replace the display-string test with a type check (`_staticTypeIsFuture`-style) AND require that the invoked element is not a member of a `Map`, `List`, `Set` or `Queue` returning a stored value (`remove`, `removeAt`, `removeLast`, `putIfAbsent`, `update`). Equivalent minimal fix: return `false` when `node.realTarget?.staticType` is one of those collection types.

---

## Fixture Gap

1. `_futureMap.remove(key);` inside a sync closure, `Map<String, Future<int?>>` — expect NO lint (new)
2. `loadData();` in a sync function, `Future<void> loadData() async {}` — expect LINT (unchanged)
3. `_sub.cancel();` in `dispose()` — expect NO lint (unchanged)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations

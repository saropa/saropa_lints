# BUG: `avoid_unawaited_future` — Fires on `StreamController.close()` / `StreamSubscription.cancel()` cleanup outside the narrow lifecycle/onDone whitelist

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `avoid_unawaited_future`
File: `lib/src/rules/core/async_rules.dart` (line ~3308, helper ~3346-3450)
Severity: False positive
Rule version: v3 | Since: (pre-13.x) | Updated: v13.12.2

---

## Summary

`avoid_unawaited_future` already contains a `_isSafeFireAndForget` allow-list whose
explicit purpose is to exempt synchronous cleanup of streams (subscription cancel,
controller close). The allow-list is too narrow: it recognizes `StreamSubscription.cancel()`
ONLY inside a method literally named `dispose` / `didUpdateWidget` / `deactivate`, and
recognizes `StreamController.close()` ONLY inside an `onDone:` / `onError:` named argument.
Real cleanup of the exact same kind — `StreamController.close()` in a plain `dispose()`,
`StreamSubscription.cancel()` in `StreamController.onCancel`, a controller `close()` in a
hand-named `disposeController()` — falls outside both branches and is flagged. These are
canonical synchronous-context cleanup sites where awaiting is impossible and pointless, and
the rule's own design intent already says they should be exempt.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_unawaited_future'" lib/src/rules/
# lib/src/rules/core/async_rules.dart:3296:    'avoid_unawaited_future',

# Negative — rule is NOT in the sibling drift-advisor repo
grep -rn "avoid_unawaited_future" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/async_rules.dart:3296`
**Rule class:** `AvoidUnawaitedFutureRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
import 'dart:async';

class CleanupExamples {
  final StreamController<bool> _queue = StreamController<bool>.broadcast();
  late final StreamSubscription<bool> _subscription;

  // Pattern 1 — StreamController.close() in a plain dispose().
  // close() returns Future<void>; in a void dispose() it cannot be awaited.
  void dispose() {
    _subscription.cancel(); // OK (matches the lifecycle branch by method name)
    _queue.close();         // LINT — false positive: close() not in the whitelist
  }

  // Pattern 2 — StreamSubscription.cancel() in StreamController.onCancel.
  Stream<bool> build(List<Stream<bool>> streams) {
    final List<StreamSubscription<bool>> subs = <StreamSubscription<bool>>[];
    final StreamController<bool> controller = StreamController<bool>();
    controller.onCancel = () {
      for (final StreamSubscription<bool> sub in subs) {
        sub.cancel(); // LINT — false positive: onCancel is not dispose/didUpdate/deactivate
      }
    };
    return controller.stream;
  }
}

class PlayerWrapper {
  SomeNativeController? controller; // close() returns Future

  // Pattern 3 — controller close() in a hand-named teardown method.
  void disposeController() {
    controller?.close(); // LINT — false positive: method name not in whitelist
    controller = null;
  }
}

abstract class SomeNativeController {
  Future<void> close();
}
```

**Frequency:** Always, for any stream/controller `close()`/`cancel()` cleanup whose enclosing
method name is not exactly `dispose`/`didUpdateWidget`/`deactivate` and is not an `onDone`/`onError` argument.

Real sites in `d:\src\contacts`:
- `lib/utils/activity/activity_queue.dart:73` — `_queue.close()` (StreamController) inside `dispose()`.
- `lib/components/user/user_profile_avatar.dart:139` — `sub.cancel()` (StreamSubscription) inside `controller.onCancel`.
- `lib/service/youtube_api/youtube_player_service.dart:31` — `controller?.close()` inside `disposeController()`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — synchronous stream/controller cleanup cannot be awaited and the rule's `_isSafeFireAndForget` is meant to exempt exactly this. |
| **Actual** | `[avoid_unawaited_future] Not awaiting a Future means any errors ... may be silently lost` reported at the `close()` / `cancel()` call. |

---

## AST Context

```
MethodDeclaration (dispose)                 ← name != dispose? NO, it IS dispose, but…
  └─ Block
      └─ ExpressionStatement
          └─ MethodInvocation (_queue.close)   ← reported here
              target staticType: StreamController<bool>
              methodName: close   ← _isControllerCloseInOnDone requires onDone/onError NAMED ARG, not dispose method
```

```
ExpressionStatement (controller.onCancel = () { ... sub.cancel(); })
  └─ FunctionExpression body
      └─ ForStatement
          └─ ExpressionStatement
              └─ MethodInvocation (sub.cancel)  ← reported here
                  target staticType: StreamSubscription<bool>
                  enclosing MethodDeclaration: build (not dispose/didUpdateWidget/deactivate)
```

---

## Root Cause

The two cleanup-exemption helpers each gate on an over-specific enclosing context.

### Hypothesis A: `_isSubscriptionCancelInLifecycle` whitelist is method-name-only and omits `onCancel`

`lib/src/rules/core/async_rules.dart:3371-3403`. After confirming `expr.methodName.name == 'cancel'`
and that the target is a `StreamSubscription`, it walks up to the first `MethodDeclaration` and
returns true only if its name is `dispose` / `didUpdateWidget` / `deactivate` (lines 3396-3398).
A `StreamSubscription.cancel()` inside a `StreamController.onCancel` assignment closure (or any
other genuinely-synchronous teardown closure) reaches a `MethodDeclaration` whose name is not in
the set, so the helper returns false and the call is flagged. `onCancel`/`onListen`/`onPause`/
`onResume` are `void Function()?` callbacks — awaiting inside them is impossible, exactly like the
lifecycle methods already whitelisted.

### Hypothesis B: `_isControllerCloseInOnDone` requires an `onDone`/`onError` named arg and ignores `dispose()`

`lib/src/rules/core/async_rules.dart:3410-3444`. For `close()` it walks up only to a `NamedExpression`
named `onDone` / `onError`, stopping at the first `MethodDeclaration`/`FunctionDeclaration`. A
`StreamController.close()` in a plain `dispose()` (or any teardown method) hits the
`MethodDeclaration` break (line 3438) before finding a named expression, so it returns false. The
single most common place to close a controller — the widget/service `dispose()` — is not covered.
The `cancel`-in-lifecycle branch covers subscriptions in `dispose()` but the symmetric
`close`-in-lifecycle case for controllers is missing entirely.

---

## Suggested Fix

In `lib/src/rules/core/async_rules.dart`:

1. **Broaden `_isSubscriptionCancelInLifecycle`** so the lifecycle walk ALSO returns true when the
   `cancel()` call is lexically inside a `StreamController` callback closure (`onCancel`, `onListen`,
   `onPause`, `onResume` named-argument or assignment to those setters). Mirror the existing
   `NamedExpression` walk used by `_isControllerCloseInOnDone`, plus an `AssignmentExpression` check
   for `x.onCancel = () {…}`.

2. **Add a `close()`-in-lifecycle branch** symmetric to the existing `cancel()`-in-lifecycle branch:
   when `expr.methodName.name == 'close'` and the target is a `StreamController`/`Sink`, walk up to the
   first `MethodDeclaration` and return true for `dispose` / `didUpdateWidget` / `deactivate`. Consider
   also accepting hand-named teardown methods whose name contains `dispose`/`close`/`teardown` — or, more
   robustly, exempt any `close()`/`cancel()` whose enclosing function body is synchronous `void`
   (awaiting is impossible there regardless of method name).

A minimal, low-risk fix is option (2)'s synchronous-`void`-body check applied to `close()`/`cancel()`/
`dispose()` invocations on `StreamController`/`StreamSubscription`/`Sink` targets: if the nearest
enclosing `FunctionBody` is not `async` and the function's declared return type is `void`, the future
cannot be awaited and the call is intentional cleanup.

---

## Fixture Gap

The fixture at `example*/lib/core/avoid_unawaited_future_fixture.dart` should include:

1. `StreamController.close()` inside a plain `dispose()` — expect NO lint
2. `StreamSubscription.cancel()` inside `controller.onCancel = () { … }` — expect NO lint
3. `StreamController.close()` inside a hand-named `disposeController()` returning `void` — expect NO lint
4. (regression guard) `someAsyncDbCall()` fire-and-forget in `initState()` — expect LINT (must still fire)

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.9.0 <4.0.0 (per pubspec environment constraint)
- analyzer: >=9.0.0 <13.0.0
- Triggering project/file: `d:\src\contacts` — `lib/utils/activity/activity_queue.dart:73`, `lib/components/user/user_profile_avatar.dart:139`, `lib/service/youtube_api/youtube_player_service.dart:31`

## Finish Report (2026-06-10)

Fixed in WS-6 via the report's robust option: a `close()`/`cancel()` in a synchronous void cleanup context (void method, hand-named teardown method, or a sync callback closure such as onCancel) is exempt — awaiting is impossible there. Covers all three patterns regardless of target type. Verified by `test/rules/core/avoid_unawaited_future_ws6_test.dart` (5 cases).

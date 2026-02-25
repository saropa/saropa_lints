# `avoid_stream_subscription_in_field` false positive: `.listen()` passed as argument to `List.add()`

## Status: RESOLVED

## Resolution

Added `ArgumentList` check in the parent-walk loop. When `.listen()` is passed as an argument to another method, the caller manages the subscription.

## Summary

The `avoid_stream_subscription_in_field` rule (v4) fires on a `.listen()` call whose return value is passed as an argument to `subscriptions.add()`, where `subscriptions` is a local `List<StreamSubscription<bool>>` managed by a `Stream.multi` factory's `onCancel` callback. The subscriptions are properly cleaned up through the cancel propagation chain: `dispose()` cancels the outer field subscription, which triggers `Stream.multi`'s `onCancel`, which cancels all inner subscriptions.

The rule's second `while` loop walks up the AST from `node.parent` and finds `ExpressionStatement` (the `subscriptions.add(stream.listen(...));` statement) before any assignment or variable declaration node, so it incorrectly classifies the `.listen()` as a "bare listen call without assignment."

## Diagnostic Output

```
resource: /D:/src/contacts/lib/components/user/user_profile_avatar.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_stream_subscription_in_field
severity: 4 (warning)
message:  [avoid_stream_subscription_in_field] If a StreamSubscription is stored as a
          field in a State class but not properly canceled in dispose(), the subscription
          will continue to receive events even after the widget is removed from the widget
          tree. This can cause memory leaks, unexpected UI updates, and subtle bugs... {v4}
lines:    123–129
```

## Affected Source

File: `lib/components/user/user_profile_avatar.dart` lines 54–144

The State class stores the outer subscription as a field and cancels it in `dispose()`:

```dart
class _UserProfileAvatarState extends State<UserProfileAvatar> {
  StreamSubscription<bool>? _rebuildTriggerSubscription;  // line 55 — field

  @override
  void initState() {
    super.initState();
    _initFutures();
    if (widget.sizeCommon.isBiggerOrEqualTo(ThemeCommonSize.Large)) {
      // Outer subscription stored in field — properly managed
      _rebuildTriggerSubscription = _createRebuildTriggerStream().listen((_) {
        if (mounted) _refreshData();
      });
    }
  }

  @override
  void dispose() {
    _rebuildTriggerSubscription?.cancel();  // line 77 — properly canceled
    super.dispose();
  }
```

The flagged code is inside `_createRebuildTriggerStream()`, which creates a `Stream.multi` that merges multiple source streams:

```dart
Stream<bool> _createRebuildTriggerStream() {
  // ...
  return Stream<bool>.multi((StreamController<bool> controller) {
    final List<StreamSubscription<bool>> subscriptions = <StreamSubscription<bool>>[];

    for (final Stream<bool> stream in streams) {
      subscriptions.add(
        stream.listen(                                         // ← FLAGGED (line 123)
          (bool _) => controller.add(true),
          onError: (Object error, StackTrace stack) {
            debugException(error, stack);
          },
        ),
      );
    }

    controller.onCancel = () {                                 // ← cleanup handler
      for (final StreamSubscription<bool> sub in subscriptions) {
        sub.cancel();                                          // ← all inner subs canceled
      }
    };
  });
}
```

### Cleanup chain (correct, no leak)

| Step | Action                                         | Trigger                     |
| ---- | ---------------------------------------------- | --------------------------- |
| 1    | `dispose()` runs                               | Widget removed from tree    |
| 2    | `_rebuildTriggerSubscription?.cancel()`        | Cancels outer subscription  |
| 3    | `Stream.multi`'s `controller.onCancel` fires   | Outer subscription canceled |
| 4    | All inner `subscriptions` are canceled in loop | `onCancel` callback         |

Every subscription is properly canceled. There is no leak.

## Root Cause

The rule implementation at `async_rules.dart` lines 2812–2830 has a second `while` loop that walks up from `node.parent` to classify the `.listen()` call:

```dart
// Second loop (lines 2813-2830)
current = node.parent;
while (current != null) {
  if (current is ExpressionStatement) {
    // This is a bare stream.listen() call without assignment
    reporter.atNode(node);    // ← FALSE POSITIVE
    return;
  }

  if (current is VariableDeclaration ||
      current is AssignmentExpression ||
      current is ReturnStatement) {
    break;  // Being assigned or returned — OK
  }

  if (current is Block || current is MethodDeclaration) {
    break;
  }
  current = current.parent;
}
```

The AST parent chain for `stream.listen(...)` in the flagged code is:

```
MethodInvocation [stream.listen(...)]
  → ArgumentList [of subscriptions.add(...)]
    → MethodInvocation [subscriptions.add(...)]
      → ExpressionStatement [subscriptions.add(stream.listen(...));]  ← MATCHED HERE
```

The loop encounters `ExpressionStatement` before any `VariableDeclaration`, `AssignmentExpression`, or `ReturnStatement`, so it treats the `.listen()` as a "bare" call. But the `.listen()` return value is not discarded — it is passed as an argument to `subscriptions.add()`, which stores it in a managed collection.

The rule does not account for `.listen()` return values passed as arguments to other method calls.

## Why This Is a False Positive

1. **The subscription IS captured** — `subscriptions.add()` stores the `StreamSubscription` in a local `List`, not discarded.

2. **The list IS cleaned up** — `controller.onCancel` iterates the list and cancels every subscription.

3. **The cancel chain IS triggered** — `dispose()` cancels `_rebuildTriggerSubscription`, which triggers `Stream.multi`'s `onCancel`.

4. **`Stream.multi` with `onCancel` is a standard Dart pattern** — the SDK documentation explicitly demonstrates this pattern for merging streams with proper cleanup.

## Scope of Impact

Any code that uses the `Stream.multi` pattern (or similar stream factory patterns) where inner `.listen()` calls are passed as arguments to a collection's `.add()` method will trigger this false positive. This is a standard Dart SDK pattern documented at https://api.dart.dev/stable/dart-async/Stream/Stream.multi.html.

Other affected patterns include:

```dart
// Pattern 1: List literal with listen calls
final subs = [stream1.listen(...), stream2.listen(...)];

// Pattern 2: Any method call wrapping listen
someHelper.track(stream.listen(...));

// Pattern 3: Cascade with listen
subscriptions..add(stream.listen(...));
```

## Recommended Fix: Check for ArgumentList Parent

### Approach A: Skip `.listen()` calls that are arguments to another method (simplest)

If the `.listen()` call is inside an `ArgumentList`, its return value is being passed to a containing method — it is not a "bare" call. The containing method is responsible for the subscription.

```dart
// In the second while loop, before checking ExpressionStatement:
if (current is ArgumentList) {
  // .listen() return value is passed as an argument to another method —
  // the caller is responsible for managing the subscription.
  return;
}
```

### Approach B: Specifically check for collection `.add()` parent (more conservative)

Only skip when the parent method call is a known collection method:

```dart
if (current is ArgumentList) {
  final AstNode? parentCall = current.parent;
  if (parentCall is MethodInvocation) {
    final String methodName = parentCall.methodName.name;
    // Collection storage methods — subscription is captured, not discarded
    if (const {'add', 'addAll', 'insert'}.contains(methodName)) {
      return;
    }
  }
}
```

### Approach C: Check if result flows into a StreamSubscription-typed variable (most precise)

Walk the full parent chain and check whether the `.listen()` result ultimately lands in a `StreamSubscription`-typed storage, regardless of the intermediate path (argument, collection, cascade, etc.). This is the most accurate but requires deeper type resolution.

**Recommendation:** Approach A is the safest and broadest fix. If `.listen()` is an argument to any method, the caller has the reference and can manage it. Approach B is more conservative but misses patterns like `someHelper.track(stream.listen(...))`. Approach C is ideal but complex.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Listen result passed to List.add() — stored and managed via onCancel.
class _good112b__StreamMultiState extends State<MyWidget> {
  StreamSubscription<bool>? _outerSub;

  @override
  void initState() {
    super.initState();
    _outerSub = _createMergedStream().listen((_) {});
  }

  @override
  void dispose() {
    _outerSub?.cancel();
    super.dispose();
  }

  Stream<bool> _createMergedStream() {
    return Stream<bool>.multi((StreamController<bool> controller) {
      final List<StreamSubscription<bool>> subs = <StreamSubscription<bool>>[];
      subs.add(
        someStream.listen((data) => controller.add(true)),
      );
      controller.onCancel = () {
        for (final sub in subs) {
          sub.cancel();
        }
      };
    });
  }
}

// GOOD: Listen result passed as argument to a tracking method.
class _good112c__TrackedListenState extends State<MyWidget> {
  final List<StreamSubscription<Object>> _subs = <StreamSubscription<Object>>[];

  @override
  void initState() {
    super.initState();
    _subs.add(someStream.listen((data) => doSomething(data)));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}

// GOOD: Listen result in a list literal — stored, not bare.
class _good112d__ListLiteralState extends State<MyWidget> {
  late final List<StreamSubscription<Object>> _subs;

  @override
  void initState() {
    super.initState();
    _subs = [
      stream1.listen((data) => handle1(data)),
      stream2.listen((data) => handle2(data)),
    ];
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Bare listen call — subscription lost, cannot be canceled.
// expect_lint: avoid_stream_subscription_in_field
class _bad112__MyWidgetState extends State<MyWidget> {
  void _init() {
    myStream.listen((data) => doSomething(data)); // Lost reference!
  }
}
```

## Environment

- **saropa_lints version:** rule version v4
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\contacts`
- **Trigger file:** `lib/components/user/user_profile_avatar.dart:123–129`
- **Trigger class:** `_UserProfileAvatarState`
- **Trigger method:** `_createRebuildTriggerStream()`
- **Trigger expression:** `stream.listen(...)` passed as argument to `subscriptions.add()`
- **Rule source:** `async_rules.dart` lines 2714–2833 (`AvoidStreamSubscriptionInFieldRule`)
- **AST path to false trigger:** `MethodInvocation → ArgumentList → MethodInvocation → ExpressionStatement`

## Severity

Medium — warning-level diagnostic. The false positive flags a correctly-managed `Stream.multi` pattern where all subscriptions are properly canceled through the cancel propagation chain. The pattern is idiomatic Dart and recommended by the SDK documentation. Following the lint's advice (storing the inner subscriptions as fields) would be unnecessary and would break the encapsulation of the stream factory method.

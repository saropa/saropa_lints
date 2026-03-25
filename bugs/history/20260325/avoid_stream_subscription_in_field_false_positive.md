# BUG: `avoid_stream_subscription_in_field` — False Positive on Properly Disposed Subscriptions

**Status: RESOLVED 2026-03-25**

**Resolution:**
- Problem 1 (no dispose checking): By design — `require_stream_subscription_cancel` handles that.
  Description updated to match actual behavior.
- Problem 2 (Stream subclass detection): Fixed — uses `isDartAsyncStream` + `allSupertypes`.
- Problem 3 (description mismatch): Fixed — problemMessage and correctionMessage rewritten.
- Fixture gap: Fixed — real `dart:async` types + `MergeStream`/`BehaviorSubject` subclass cases.

Created: 2026-03-25
Rule: `avoid_stream_subscription_in_field`
File: `lib/src/rules/core/async_rules.dart` (line ~2964)
Severity: False positive — forces unnecessary `// ignore:` suppressions on correct code
Rule version: v4 | Since: v2.3.7 | Updated: v4.13.0

---

## Summary

The rule's **name and description** promise it only fires when a `StreamSubscription` field is "not properly canceled in dispose()." The **actual detection logic** never checks `dispose()` at all. It only checks whether a `.listen()` call's return value is captured in a variable. This creates two distinct problems.

---

## Problem 1: Rule Does Not Check `dispose()` (Description vs. Implementation Mismatch)

### Documented behavior (from `_code.problemMessage`)

> "If a StreamSubscription is stored as a field in a State class **but not properly canceled in dispose()**, the subscription will continue to receive events..."

### Actual behavior

The `runWithReporter` method at line 3006 registers a single `addMethodInvocation` callback that:

1. Finds `.listen()` calls on `Stream`-typed targets
2. Walks up the AST checking whether the return value is assigned to a `StreamSubscription`-typed variable or a variable whose name ends with `Subscription` / is in `_subscriptionVarNames`
3. If captured → no lint. If bare/discarded → lint.

**There is zero inspection of `dispose()`.** The rule cannot distinguish between:

```dart
// A: Properly disposed — should NOT lint
StreamSubscription<int>? _sub;
void initState() { _sub = stream.listen(handler); }
void dispose() { _sub?.cancel(); super.dispose(); }

// B: Never disposed — SHOULD lint per the description, but doesn't
StreamSubscription<int>? _sub;
void initState() { _sub = stream.listen(handler); }
// dispose() missing or doesn't cancel _sub
```

Both pass the name/type check and are silently accepted.

### Impact

Users who store a subscription but forget to cancel it in `dispose()` get **no warning**, which is the primary use case described in the rule's own documentation.

---

## Problem 2: `Stream` Subclass Detection Gap (rxdart and Custom Streams)

The stream-type check at line 3020–3021:

```dart
final String typeName = type.getDisplayString();
if (!typeName.startsWith('Stream')) return;
```

This only matches types whose display string starts with `Stream`. Subclasses from rxdart (`MergeStream`, `CombineLatestStream`, `SwitchLatestStream`, `BehaviorSubject`, etc.) return display strings like `MergeStream<void>`, which do **not** start with `Stream`.

Any `.listen()` call on an rxdart operator result **bypasses the rule entirely** — whether the subscription is captured or not.

### Reproducer

```dart
class _MyState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    // This bare .listen() is never captured — a real leak.
    // But the rule does NOT fire because Rx.merge returns MergeStream<void>.
    Rx.merge<void>([streamA, streamB]).listen((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

### Fix

Check `type.allSupertypes` for `Stream` ancestry instead of a string prefix:

```dart
bool _isStreamType(DartType type) {
  if (type is InterfaceType) {
    if (type.element.name == 'Stream') return true;
    return type.allSupertypes.any((DartType t) =>
        t is InterfaceType && t.element.name == 'Stream');
  }
  return false;
}
```

---

## Problem 3: Field-Level `// ignore:` Does Not Suppress `.listen()`-Level Warning

Because the rule fires on the `.listen()` **MethodInvocation** node (line 3035/3088: `reporter.atNode(node)` where `node` is the `.listen()` call), placing `// ignore: avoid_stream_subscription_in_field` above the **field declaration** does not suppress the warning. The ignore must be placed above the `.listen()` call site.

This is confusing because the rule name says "in field" — users naturally put the ignore on the field.

---

## Real-World False Positive Trigger

File: `contacts/lib/components/user/user_profile_avatar.dart`

```dart
// Merged trigger stream — fires whenever privacy, user UUID, or auth
// changes — so the avatar rebuilds without checking individual streams.
// ignore: avoid_stream_subscription_in_field
StreamSubscription<void>? _rebuildTriggerSubscription;

@override
void initState() {
  super.initState();
  _initStreams();
}

void _initStreams() {
  _rebuildTriggerSubscription = Rx.merge<void>([
    privacySettingStream,
    currentUserUUIDStream,
    authStateStream,
  ]).listen((_) {
    if (mounted) setState(() {});
  });
}

@override
void dispose() {
  _rebuildTriggerSubscription?.cancel();
  super.dispose();
}
```

This code:
- Stores the subscription in a properly-typed field (name ends with `Subscription`)
- Cancels it in `dispose()` before `super.dispose()`
- Follows the exact pattern shown in the rule's own "GOOD" docstring example

The `// ignore:` was added because the rule fires (or was observed to fire). Given the detection logic, the name check at line 3047 (`leftSource.endsWith('Subscription')`) should actually allow this. If the rule is NOT firing here, the `// ignore:` is a dead suppression caused by the confusing rule name/description making users add it preemptively — which is also a bug (of documentation).

---

## Suggested Fixes

1. **Add `dispose()` inspection**: Walk the enclosing State class's `dispose()` method and verify that `fieldName.cancel()` or `fieldName?.cancel()` is called. Only lint if disposal is missing. This matches the documented behavior.

2. **Fix stream type detection**: Use type hierarchy checking instead of `getDisplayString().startsWith('Stream')` to catch rxdart and custom `Stream` subclasses.

3. **Align name and description with behavior**: If the rule intentionally does NOT check `dispose()`, update the description to say "warns when .listen() is called without capturing the subscription" and rename to something like `avoid_uncaptured_stream_listen`.

4. **Report at field declaration, not `.listen()` call**: If the intent is to flag bad fields, report on the field node so `// ignore:` placement is intuitive.

---

## Fixture Gap

The fixture at `example_async/lib/async/avoid_stream_subscription_in_field_fixture.dart` does not include:

- A case with rxdart stream types (`Rx.merge`, `BehaviorSubject`, etc.)
- A case where subscription is stored but `dispose()` is missing (the documented bad pattern)
- A case where `.listen()` is in a helper method called from `initState()` rather than directly in `initState()`

---

## Environment

- saropa_lints rule version: v4
- Dart SDK: 3.x
- Triggering package: rxdart (Rx.merge)

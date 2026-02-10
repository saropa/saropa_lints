# Bug: `prefer_stream_distinct` produces false positives on void and periodic streams

**Rule:** `prefer_stream_distinct`
**File:** `lib/src/rules/async_rules.dart` lines 3604-3683
**Severity:** High - following the lint suggestion breaks working code

---

## Summary

The `prefer_stream_distinct` rule recommends adding `.distinct()` before
`.listen()` to skip duplicate consecutive values. This is sound advice for
data-carrying streams like `Stream<int>` or `Stream<String>`, but the rule
does not account for cases where `.distinct()` would **silently suppress all
events after the first**, breaking timer streams, signal-only streams, and
similar patterns.

---

## Issue 1: `Stream.periodic` false positive (breaks timer)

`Stream<void>.periodic(duration)` emits a `null` value every tick. Adding
`.distinct()` causes `null == null` to evaluate as `true` on every subsequent
event, filtering out **all ticks after the first**. The timer fires once and
then silently stops.

### Reproduction

```dart
// FLAGGED by lint - suggests adding .distinct()
_subscription = Stream<void>.periodic(
  const Duration(seconds: 1),
).listen((_) {
  setState(() {}); // Rebuild every second (e.g. clock widget)
});

// FOLLOWING the lint suggestion BREAKS the timer:
_subscription = Stream<void>.periodic(
  const Duration(seconds: 1),
).distinct().listen((_) {
  setState(() {}); // Only fires ONCE, then silent forever
});
```

### Real-world example

`auto_refreshing_date_time.dart` uses `Stream<void>.periodic` to update a
clock display every second. The lint was suppressed with
`// ignore: prefer_stream_distinct` because following it would freeze the
clock after one tick.

---

## Issue 2: `Stream<void>` signal streams

Isar's `watchLazy()` and similar APIs return `Stream<void>` to signal "something
changed" without carrying data. Every event is a `null` value. Adding
`.distinct()` would suppress all change notifications after the first, causing
the UI to stop reacting to database changes.

```dart
// watchLazy() returns Stream<void> - every event is null
_subscription = isar.contactDBModels
    .watchLazy(fireImmediately: false)
    .distinct()  // null == null -> filters ALL events after first
    .listen((_) {
      setState(() {}); // Only fires once, ignores subsequent DB changes
    });
```

This is particularly dangerous because the failure is silent - the app
appears to work on initial load but stops updating when data changes.

---

## Issue 3: Chain detection only checks immediate parent

The rule checks whether `.distinct()` is the **immediate** method call before
`.listen()`. Chained operations break this detection:

```dart
// .distinct() IS present but not detected - FALSE POSITIVE
stream
    .distinct()           // <-- present
    .debounce(duration)   // <-- this is the immediate parent of .listen()
    .listen((_) {
      setState(() {});
    });

// .distinct() IS present but not detected - FALSE POSITIVE
stream
    .distinct()
    .map((v) => transform(v))
    .listen((_) {
      setState(() {});
    });
```

The rule only inspects `node.target` (one level up). It should walk the full
method invocation chain to find `.distinct()` at any position.

---

## Issue 4: `setStateSafe` and wrapper patterns not detected

The rule checks for `setState` in the listener body using string matching
(`body.contains('setState')`). Common safe-setState wrappers are missed:

```dart
// NOT flagged - no raw "setState" in body
stream.listen((_) {
  _setStateSafe();  // contains "setState" as substring - actually IS detected
});

// NOT flagged - indirect setState
stream.listen((_) {
  setStateSafe();   // Mixin method - contains "setState" - IS detected
});

// NOT flagged - actually problematic
stream.listen((_) {
  _refresh();       // _refresh() calls setState internally - NOT detected
});
```

This is a minor issue since the string match catches `setStateSafe` as a
substring of `setState`. But indirect calls through helper methods are missed.

---

## Suggested fixes

### Fix 1: Exclude `Stream<void>` type parameter

If the stream's generic type argument is `void`, `.distinct()` will always
filter out duplicates because all void values are equal. The rule should skip
these streams entirely.

```dart
// In runWithReporter, after checking targetType:
final typeArgs = targetType is InterfaceType ? targetType.typeArguments : null;
if (typeArgs != null && typeArgs.length == 1) {
  final elementType = typeArgs.first;
  if (elementType is VoidType) return; // void streams: distinct breaks them
}
```

### Fix 2: Exclude `Stream.periodic` factory constructor

Detect when the stream originates from `Stream.periodic` and skip the lint.
This could be done by walking the expression tree to find the stream source.

### Fix 3: Walk the full method chain for `.distinct()`

Instead of checking only the immediate parent:

```dart
// Current (broken for chains):
final target = node.target;
if (target is MethodInvocation) {
  if (target.methodName.name == 'distinct') return;
}

// Proposed (walks full chain):
Expression? current = node.target;
while (current is MethodInvocation) {
  if (current.methodName.name == 'distinct') return;
  current = current.target;
}
```

This correctly handles chains like
`stream.distinct().debounce(d).map(f).listen(...)`.

---

## Priority

**Issue 1** is the highest priority because following the lint actively breaks
code. Users who trust the lint and add `.distinct()` to periodic streams will
introduce subtle bugs (timers/clocks that fire once then stop).

**Issue 2** is equally dangerous for `watchLazy()` and similar signal streams
where `.distinct()` causes the UI to stop reacting to changes after the first.

**Issue 3** causes false positives that waste developer time but does not cause
broken code (it just means the lint fires when `.distinct()` is already
present in the chain).

---

## Files affected in saropa contacts app

| File | Stream type | Workaround used |
|------|-------------|-----------------|
| `auto_refreshing_date_time.dart` | `Stream<void>.periodic` | `// ignore: prefer_stream_distinct` |

---

## Test case suggestions

```dart
// Should NOT lint - Stream<void>.periodic
Stream<void>.periodic(const Duration(seconds: 1)).listen((_) {
  setState(() {});
});

// Should NOT lint - Stream.periodic with void
Stream.periodic(const Duration(seconds: 1)).listen((_) {
  setState(() {});
});

// Should NOT lint - .distinct() already in chain before .debounce()
stream.distinct().debounce(const Duration(milliseconds: 500)).listen((_) {
  setState(() {});
});

// Should NOT lint - .distinct() already in chain before .map()
stream.distinct().map((v) => v.toString()).listen((_) {
  setState(() {});
});

// SHOULD lint - data-carrying stream without .distinct()
stream.listen((int value) {
  setState(() => _value = value);
});

// Should NOT lint - Stream<void> from watchLazy
isar.collection.watchLazy().listen((_) {
  setState(() {});
});
```

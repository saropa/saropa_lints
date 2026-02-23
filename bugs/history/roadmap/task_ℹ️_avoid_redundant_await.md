# Task: `avoid_redundant_await`

## Summary
- **Rule Name**: `avoid_redundant_await`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Using `await` on an expression that is already synchronous (not a `Future`) is wasteful and misleading. It implies to the reader that the expression is asynchronous when it is not, creates confusion about the control flow, and adds a micro-overhead because `await` still yields to the event loop even when the value is not a Future. In async functions this is a common copy-paste artifact where a developer wraps every call in `await` out of habit. The rule should flag these redundant awaits so callers can remove them and signal true intent.

## Description (from ROADMAP)
Flags `await` used on non-Future expressions in async functions, where the await is a no-op.

## Trigger Conditions
- The expression is inside an `async` function body.
- The `await` keyword is applied to an expression whose static type is **not** a subtype of `Future<T>`, `FutureOr<T>`, or `Stream<T>`.
- The expression's static type is a concrete non-nullable type such as `int`, `String`, `bool`, a class instance, a list literal, etc.
- The called function (if any) is not declared `async` and does not return `Future`.

## Implementation Approach

### AST Visitor
```dart
context.registry.addAwaitExpression((node) {
  // inspection happens here
});
```

### Detection Logic
1. Obtain the `AwaitExpression` node.
2. Get the static type of `node.expression` (the thing being awaited).
3. Retrieve the `TypeSystem` from the resolver session.
4. Check whether the static type is assignable to `Future<dynamic>` or `FutureOr<dynamic>`.
5. Also check whether the static type is assignable to `Stream<dynamic>` (awaiting a Stream is also valid).
6. If the type is neither a `Future` nor a `FutureOr` nor a `Stream`, and the type is not `dynamic`, `Object`, or a type parameter (unconstrained generic), report the node.
7. Do not report if the static type is null (cannot be determined — avoid false positives).

## Code Examples

### Bad (triggers rule)
```dart
Future<void> process() async {
  final x = await 42;                   // int is not a Future
  final name = await 'hello';           // String is not a Future
  final flag = await true;              // bool is not a Future
  final items = await [1, 2, 3];        // List<int> is not a Future
  await nonAsyncMethod();               // void return is not a Future
  final result = await computeSync();   // returns int, not Future<int>
}

int computeSync() => 100;
void nonAsyncMethod() {}
```

### Good (compliant)
```dart
Future<void> process() async {
  final x = 42;
  final name = 'hello';
  final flag = true;
  final items = [1, 2, 3];
  nonAsyncMethod();
  final result = computeSync();

  // These ARE appropriate awaits:
  final data = await fetchData();         // Future<String>
  final value = await futureOrValue();    // FutureOr<int>
  await Future.delayed(Duration.zero);    // Future<void>
}

Future<String> fetchData() async => 'data';
FutureOr<int> futureOrValue() => 1;
void nonAsyncMethod() {}
int computeSync() => 100;
```

## Edge Cases & False Positives
- **`await null`**: `null` has type `Null` which is not a `Future`, but `null` is a common intentional sentinel in some patterns. Still flag it — returning `null` from a Future context should use `Future.value(null)` or be async.
- **`FutureOr<T>` types**: `FutureOr<int>` can be either a `Future<int>` or an `int`. The await is valid in this case because the runtime value may be a Future. Do NOT flag `FutureOr<T>`.
- **Generic type parameters**: If the type is `T` (unconstrained) or `T extends Object`, do NOT flag — the type may resolve to a Future at runtime.
- **`dynamic` type**: Skip — we cannot determine at compile time whether it is a Future.
- **`Object` type**: Skip for same reason.
- **Tear-offs awaited**: `await someMethod` where `someMethod` is a method reference evaluating to a `Future Function()` — the type is `Future Function()`, which is not a Future itself but the intent is to call it. Flag this (the await is on the function object, not a call result).
- **Platform channels**: Some platform channel calls are `Future`-typed even if they look synchronous. Check the static type, not the method name.
- **Extension types wrapping Future**: If an extension type has representation type `Future<T>`, it may or may not be awaitable depending on whether it implements `Future`. Use type assignability checks, not string matching.
- **`await for`**: `await for (final item in stream)` is valid — do not touch `ForStatement` or `ForEachStatement` with `await`; these are separate AST nodes.

## Unit Tests

### Should Trigger (violations)
```dart
// Violation: awaiting int literal
Future<void> awaitInt() async {
  final x = await 42; // LINT
}

// Violation: awaiting String literal
Future<void> awaitString() async {
  final s = await 'hello'; // LINT
}

// Violation: awaiting bool
Future<void> awaitBool() async {
  final b = await true; // LINT
}

// Violation: awaiting synchronous function call
int syncFn() => 0;
Future<void> awaitSyncCall() async {
  final v = await syncFn(); // LINT
}

// Violation: awaiting a list literal
Future<void> awaitList() async {
  final list = await [1, 2, 3]; // LINT
}

// Violation: await on void function
void doThing() {}
Future<void> awaitVoid() async {
  await doThing(); // LINT
}
```

### Should NOT Trigger (compliant)
```dart
// OK: awaiting a Future
Future<String> fetchName() async => 'Alice';
Future<void> awaitFuture() async {
  final name = await fetchName();
}

// OK: awaiting FutureOr
FutureOr<int> maybeAsync() => 1;
Future<void> awaitFutureOr() async {
  final v = await maybeAsync();
}

// OK: awaiting Future.delayed
Future<void> delay() async {
  await Future.delayed(const Duration(milliseconds: 100));
}

// OK: generic type parameter (could be Future at runtime)
Future<T> wrap<T>(T value) async {
  return await value as T; // T is unconstrained — skip
}

// OK: dynamic type
Future<void> awaitDynamic(dynamic x) async {
  await x; // dynamic — cannot determine
}

// OK: await for is a separate construct, not flagged
Future<void> awaitFor(Stream<int> stream) async {
  await for (final item in stream) {
    print(item);
  }
}
```

## Quick Fix
Remove the `await` keyword from the expression.

- Simple case: `final x = await 42;` → `final x = 42;`
- Statement case: `await nonAsyncMethod();` → `nonAsyncMethod();`

The fix should:
1. Identify the `AwaitExpression` node's source range.
2. Replace the `AwaitExpression` with its inner `expression` text (i.e., strip `await ` prefix).
3. If the entire statement is just `await expr;`, replace with `expr;`.

## Notes & Issues
- Dart SDK minimum: 2.0 (async/await).
- The `TypeSystem.isAssignableTo` or `TypeSystem.isSubtypeOf` methods on the analyzer's `TypeSystem` interface are the correct way to check Future assignability.
- Avoid using string matching on type names (e.g., `type.toString().contains('Future')`) — use the type hierarchy APIs.
- The enclosing function must be `async` for `await` to be syntactically valid. The rule only fires inside async contexts, so no need to check separately — the parser would reject `await` outside async.
- Performance: `addAwaitExpression` is called only at await sites, so this is inherently scoped and fast. No full-file traversal needed.
- Dart's `await` on a non-Future value actually wraps it in `Future.value(x)` at runtime, so the code is not broken — it is just misleading and slightly wasteful. This is an INFO-level finding, not an error.

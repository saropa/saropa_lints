# Task: `avoid_returning_null_for_future`

## Summary
- **Rule Name**: `avoid_returning_null_for_future`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Async

## Problem Statement
Returning `null` from a non-async method declared to return `Future<T>` (non-nullable) bypasses async mechanics and misleads callers. When a caller `await`s such a method, they get a `Null` instead of a real `Future`, causing a `Null check operator used on a null value` crash or a type error at runtime if the code assumes a non-null Future. This is a design smell: if the intent is to return an already-complete value, the method should be `async` (returning `Future.value(value)` implicitly) or explicitly wrap the return in `Future.value()`. Returning raw `null` for a non-nullable Future type is almost certainly a bug or an oversight from pre-null-safety code that was mechanically migrated.

## Description (from ROADMAP)
Detects `return null` inside non-async methods whose declared return type is a non-nullable `Future<T>`, signaling a likely bug or incomplete null-safety migration.

## Trigger Conditions
- The enclosing function or method is **not** `async`.
- The declared return type is `Future<T>` where `T` is any type.
- The return type is **non-nullable** (i.e., not `Future<T>?`).
- The return statement value is a `NullLiteral` (`null`).

## Implementation Approach

### AST Visitor
```dart
context.registry.addReturnStatement((node) {
  // inspection happens here
});
```

### Detection Logic
1. Check whether `node.expression` is a `NullLiteral`. If not, skip.
2. Walk up the AST to find the enclosing function body: `FunctionBody`.
3. Check that the enclosing function body is NOT an `AsyncFunctionBody` (i.e., does not have the `async` keyword). If async, skip.
4. Obtain the declared return type of the enclosing function/method:
   - For `FunctionDeclaration`: `element.returnType`.
   - For `MethodDeclaration`: `element.returnType`.
5. Check that the return type's `isDartAsyncFuture` is true (use `DartType.isDartAsyncFuture`) OR that the type's element is `Future` from `dart:async`.
6. Check that the return type is **not** nullable (i.e., `type.nullabilitySuffix != NullabilitySuffix.question`).
7. If all conditions hold, report the `ReturnStatement` node.

## Code Examples

### Bad (triggers rule)
```dart
// Non-async method returning null for Future<String>
Future<String> fetchName() {
  if (_cache != null) return _cache!;
  return null; // LINT: null is not a Future<String>
}

// Non-async method, Future<int> return type
Future<int> computeValue(bool ready) {
  if (!ready) return null; // LINT
  return Future.value(42);
}

// Conditional early exit returning null
Future<Map<String, dynamic>> loadConfig(String? path) {
  if (path == null) return null; // LINT
  return _readFile(path);
}
```

### Good (compliant)
```dart
// Option 1: make the method async
Future<String> fetchName() async {
  if (_cache != null) return _cache!;
  return 'default';
}

// Option 2: wrap in Future.value
Future<String> fetchName() {
  if (_cache != null) return _cache!;
  return Future.value(null); // only if return type is Future<String?>
}

// Option 3: nullable Future is OK
Future<String?>? fetchMaybeName() {
  return null; // Future<String?>? — null is a valid return
}

// Option 4: async method — returning null from async is fine
Future<String?> fetchOptional() async {
  return null; // async method, Future<String?> — OK
}

// Option 5: return Future.error for error cases
Future<String> fetchName() {
  if (!ready) return Future.error(StateError('Not ready'));
  return Future.value('Alice');
}
```

## Edge Cases & False Positives
- **`Future<T>?` return type (nullable Future)**: `null` is a valid return value — the method may intentionally return "no Future". Do NOT flag.
- **`async` methods**: In an async method, `return null;` is equivalent to `return Future.value(null)` — fully valid. Do NOT flag.
- **`FutureOr<T>` return type**: `null` is invalid for non-nullable `FutureOr<T>` but this is a different type. Consider flagging as a separate rule or extending this rule. For now, focus only on `Future<T>`.
- **Factory constructors returning Future**: These are unusual but syntactically valid; apply the same logic.
- **Tear-off context**: If the method is used as a tear-off, changing it may affect the signature. Note in the fix description.
- **`return;` (bare return in Future method)**: This is a different scenario (omitting the value entirely). Some versions of Dart accept this for `Future<void>`. Do not flag bare returns here; focus only on explicit `return null;`.
- **Generated code**: Files with `.g.dart` or `.freezed.dart` suffixes may contain this pattern intentionally. Consider adding a suppression mechanism or skipping generated files.
- **Pre-null-safety code**: With `// @dart=2.9` language version markers, nullability rules differ. Respect the effective language version when checking nullability.

## Unit Tests

### Should Trigger (violations)
```dart
// Violation: non-async, non-nullable Future<String>, returns null
Future<String> bad1() {
  return null; // LINT
}

// Violation: conditional null return
Future<int> bad2(bool ready) {
  if (!ready) return null; // LINT
  return Future.value(0);
}

// Violation: inside a class method
class Repo {
  Future<String> fetch() {
    return null; // LINT
  }
}
```

### Should NOT Trigger (compliant)
```dart
// OK: nullable Future return type
Future<String>? ok1() {
  return null;
}

// OK: async method
Future<String> ok2() async {
  return null; // async — null becomes Future.value(null); only valid if Future<String?>
}

// OK: future returned properly
Future<String> ok3() {
  return Future.value('hello');
}

// OK: Future<void>, returning null is debatable but common
Future<void> ok4() {
  return Future.value();
}

// OK: bare return (no expression) in Future<void>
Future<void> ok5() {
  return;
}
```

## Quick Fix
Two fix options should be offered:

**Fix 1**: Wrap with `Future.value(null)` (for nullable result types):
- `return null;` → `return Future.value(null);`
- Only applicable if the return type accepts `Future<Null>` (i.e., the `T` is nullable or is `void`).

**Fix 2**: Add `async` to the function:
- Adds `async` keyword to the function body.
- `return null;` becomes valid as `return null;` inside async (result is `Future<Null>`).
- Caller may need to verify that `Future<String>` vs `Future<String?>` is acceptable.
- This fix is higher-priority when the overall function structure is simple.

The quick fix builder should:
1. Find the enclosing `FunctionDeclaration` or `MethodDeclaration` node.
2. For Fix 1: Replace `null` in the return statement with `Future.value(null)`.
3. For Fix 2: Insert `async` before the function body's opening brace.

## Notes & Issues
- Dart version: This rule applies to null-safe code (Dart 2.12+). For pre-null-safety code, `Future<String>` could always be null and this pattern was valid.
- The `isDartAsyncFuture` property on `DartType` is the canonical way to check for `dart:async Future`. Use it instead of checking `type.element?.name == 'Future'`.
- The rule should check the effective language version of the file being analyzed and skip files with `@dart<2.12`.
- Related rules: `avoid_returning_null_for_void` (separate rule), `avoid_redundant_await`.
- Priority ordering for the fix: prefer Fix 2 (add async) when the function has only one return point; prefer Fix 1 when multiple return paths exist.

# Bug: `avoid_unnecessary_nullable_return_type` false positive when delegating to nullable methods

## Resolution

**Fixed.** `_expressionCanBeNull` checks `staticType.nullabilitySuffix` — method calls returning nullable types are correctly recognized.


## Summary

The `avoid_unnecessary_nullable_return_type` rule incorrectly flags methods
whose nullable return type comes from delegating to another method that itself
returns a nullable type. The rule fails to trace nullability through method
calls such as `someString.nullIfEmpty()` (returns `String?`) or
`removeConsecutiveSpaces()` (returns `String?`).

## Severity

**False positive** -- removing the `?` from the return type would cause a
compile-time error because the delegate method's return type is `String?`
and Dart's type system will not allow assigning `String?` to `String` without
a null check.

## Reproduction

### Minimal example 1: Delegation to `nullIfEmpty()`

```dart
extension StringExtensions on String {
  /// Returns null if empty, otherwise returns trimmed string.
  String? nullIfEmpty({bool trimFirst = true}) {
    if (isEmpty) return null;
    if (trimFirst) {
      final String trimmed = trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return this;
  }

  // FLAGGED: avoid_unnecessary_nullable_return_type
  //          "Return type is nullable but function never returns null"
  String? removeStart(String? start, {
    bool isCaseSensitive = true,
    bool trimFirst = false,
  }) {
    if (trimFirst) {
      return trim().removeStart(start, isCaseSensitive: isCaseSensitive);
    }
    if (start == null || start.isEmpty) {
      return this;
    }
    if (isCaseSensitive) {
      // substringSafe(start.length).nullIfEmpty() returns String?
      return startsWith(start)
          ? substringSafe(start.length).nullIfEmpty()  // <-- String?
          : this;
    }
    return toLowerCase().startsWith(start.toLowerCase())
        ? substringSafe(start.length).nullIfEmpty()    // <-- String?
        : this;
  }
}
```

### Minimal example 2: Delegation to another nullable method

```dart
extension StringExtensions on String {
  /// Returns null for empty input.
  String? removeConsecutiveSpaces({bool trim = true}) {
    if (isEmpty) return null;
    final String replaced = replaceAll(RegExp(r'\s+'), ' ');
    return replaced.nullIfEmpty(trimFirst: trim);
  }

  // FLAGGED: avoid_unnecessary_nullable_return_type
  //          "Return type is nullable but function never returns null"
  String? compressSpaces({bool trim = true}) =>
      removeConsecutiveSpaces(trim: trim);   // <-- returns String?
}
```

### Why the return IS nullable

```dart
// removeStart
'hello'.removeStart('hello');                        // null (via nullIfEmpty())
'  hello  '.removeStart('hello', trimFirst: true);   // null (after trim + remove)

// compressSpaces
''.compressSpaces();                                 // null (empty input)
'   '.compressSpaces();                              // null (whitespace-only)
```

### Lint output

```
line 320 col 3 • [avoid_unnecessary_nullable_return_type] Return type is
nullable but function never returns null. Unnecessary nullability forces
callers to add redundant null checks, reducing code clarity and type
safety. {v3}
```

### All affected locations (2 instances)

| File | Line | Method | Delegates to |
|------|------|--------|--------------|
| `lib/string/string_extensions.dart` | 320 | `removeStart` | `nullIfEmpty()` which returns `String?` |
| `lib/string/string_extensions.dart` | 413 | `compressSpaces` | `removeConsecutiveSpaces()` which returns `String?` |

## Root cause

The rule determines "function never returns null" by inspecting the function
body for null-producing patterns (likely `NullLiteral` nodes). However, when
the function delegates to another method that returns a nullable type, there
is no `NullLiteral` in the calling function's body -- the null comes from
the callee.

### The detection gap

```dart
// This is detected (NullLiteral present in body):
String? a() {
  if (isEmpty) return null;  // ReturnStatement → NullLiteral ✓
  return this;
}

// This is NOT detected (no NullLiteral in body):
String? b() {
  return someMethod();  // ReturnStatement → MethodInvocation
                        // someMethod() returns String?, but no NullLiteral here
}
```

The rule would need to resolve the return type of `someMethod()` to determine
that the expression's static type is `String?`, which means the function
can indeed return `null`.

## Suggested fix

Check the **static type** of each return expression. If the expression's
static type is nullable, the function's nullable return type is justified:

```dart
void analyzeReturnExpression(Expression expr, DartType declaredReturnType) {
  final exprType = expr.staticType;
  if (exprType != null &&
      exprType.nullabilitySuffix == NullabilitySuffix.question) {
    // Return expression has nullable type -- nullable return type is valid
    return; // Do not report
  }
}
```

This single check (static type nullability) would fix this bug category AND
the Map operator false positive AND the conditional branch false positive,
since all of them share the same underlying issue: the return expression has
a nullable static type that the rule ignores.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Delegates to method returning String?
String? nullIfEmpty() => isEmpty ? null : this;
String? wrapper() => nullIfEmpty();  // Should NOT flag

// Delegates to standard library nullable method
String? firstMatch(String pattern) => RegExp(pattern).firstMatch(this)?.group(0);

// Chains through nullable method
String? clean() => trim().nullIfEmpty();

// Recursive delegation
String? process() => trim().process();  // returns String?

// Should STILL flag (true positives, no change):

// Delegates to method returning non-null String
String? bad() => toString();  // toString() returns String, not String?

// Delegates to non-null extension method
String? alsobad() => trim();  // trim() returns String, not String?
```

## Impact

This affects any method that wraps or delegates to another nullable method.
Common patterns include:
- Wrapper methods (aliases, convenience methods)
- Method chains ending in nullable methods
- Recursive calls to nullable methods
- Builder/transformer patterns where intermediate results can be null

In the `saropa_dart_utils` codebase, `nullIfEmpty()` is used extensively as a
pipeline terminator, and any method that calls it inherits the nullable return
type. The lint would need to be suppressed on every such method.

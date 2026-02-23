# Bug: `avoid_unnecessary_nullable_return_type` false positive on Map `[]` operator

## Resolution

**Fixed.** `_expressionCanBeNull` now checks `staticType.nullabilitySuffix` — map `[]` operator returns `V?` which is correctly recognized.


## Summary

The `avoid_unnecessary_nullable_return_type` rule incorrectly flags methods
whose return type is `String?` when the nullable value comes from a `Map<K, V>`
subscript operator (`map[key]`). The Map `[]` operator returns `V?` (nullable)
because the key may not exist in the map, but the lint rule fails to recognize
this nullable source and reports the return type as unnecessarily nullable.

## Severity

**False positive** -- the rule demands removing `?` from return types that
genuinely can return `null`, which would produce a compile-time error or runtime
`TypeError`. Developers who follow the lint suggestion will introduce crashes.

## Reproduction

### Minimal example

```dart
class MonthUtils {
  static const Map<int, String> monthLongNames = <int, String>{
    1: 'January',
    2: 'February',
    // ... 3-12 omitted
  };

  // FLAGGED: avoid_unnecessary_nullable_return_type
  //          "Return type is nullable but function never returns null"
  static String? getMonthLongName(int month) => monthLongNames[month];
}
```

### Why the return IS nullable

```dart
MonthUtils.getMonthLongName(1);  // 'January'
MonthUtils.getMonthLongName(0);  // null (key not in map)
MonthUtils.getMonthLongName(13); // null (key not in map)
MonthUtils.getMonthLongName(-1); // null (key not in map)
```

The `Map<int, String>` operator `[]` has signature `String? operator [](Object? key)`.
When the key is not present, it returns `null`. The return type `String?` is
therefore **correct and required**.

### Lint output

```
line 123 col 10 • [avoid_unnecessary_nullable_return_type] Return type is
nullable but function never returns null. Unnecessary nullability forces callers
to add redundant null checks, reducing code clarity and type safety. {v3}
```

### All affected locations (4 instances)

| File | Line | Method | Expression |
|------|------|--------|------------|
| `lib/datetime/date_constants.dart` | 123 | `getMonthLongName` | `monthLongNames[month]` |
| `lib/datetime/date_constants.dart` | 127 | `getMonthShortName` | `month == null ? null : monthShortNames[month]` |
| `lib/datetime/date_constants.dart` | 158 | `getDayLongName` | `dayOfWeek == null ? null : dayLongNames[dayOfWeek]` |
| `lib/datetime/date_constants.dart` | 163 | `getDayShortName` | `dayOfWeek == null ? null : dayShortNames[dayOfWeek]` |

Note: Lines 127, 158, and 163 have a **double nullable source**: both the
explicit `null` in the ternary and the Map `[]` operator. The lint misses both.

## Root cause

The rule's "never returns null" analysis does not model the nullable return type
of `Map<K, V>.operator[]`. The Dart type system defines:

```dart
abstract class Map<K, V> {
  V? operator [](Object? key);  // Always returns V?, not V
}
```

When a function body is a single expression `map[key]`, the expression's static
type is `V?`. The rule should check the **static type of the return expression**
against the declared return type. If the expression's type is already nullable,
the nullable return type is justified.

### Likely detection gap

The rule probably walks the AST looking for explicit `null` literals (`return null;`)
or `NullLiteral` nodes. Since `map[key]` is an `IndexExpression` that *resolves*
to `V?` at the type level but does not contain a literal `null` in the AST, the
rule concludes "function never returns null." This is incorrect -- the function
returns a value of type `V?`, which includes `null`.

## Suggested fix

When analyzing whether a function "can return null," the rule must also check
the **static type** of the returned expression. If any return expression has a
nullable static type (i.e., `staticType?.nullabilitySuffix == NullabilitySuffix.question`),
the nullable return type is justified and the rule should not fire.

```dart
// Pseudocode for the fix
void checkReturnExpression(Expression returnExpr) {
  final DartType? exprType = returnExpr.staticType;
  if (exprType != null &&
      exprType.nullabilitySuffix == NullabilitySuffix.question) {
    // The expression itself can produce null -- nullable return type is valid
    return; // Do not report
  }
  // ... existing null-literal detection logic
}
```

This covers not only Map `[]` but any method/property that returns a nullable type:
- `List<T>.firstOrNull` (returns `T?`)
- `Map.remove()` (returns `V?`)
- `Iterable<T>.singleOrNull` (returns `T?`)
- `RegExpMatch.group()` (returns `String?`)
- Any user-defined method returning a nullable type

## Test cases to add

```dart
// Should NOT flag (false positives to fix):
class MapReturn {
  static const Map<int, String> _names = {1: 'a', 2: 'b'};

  // Map [] operator returns String? -- nullable return type is correct
  static String? getName(int id) => _names[id];

  // Ternary with null + Map [] -- both sources are nullable
  static String? getNameSafe(int? id) => id == null ? null : _names[id];

  // Map.remove() returns V? -- nullable return type is correct
  static String? removeName(int id) => _names.remove(id);
}

// Should STILL flag (true positives, no change):
class NonNullReturn {
  // toString() always returns non-null String
  static String? bad() => 42.toString();

  // String interpolation always returns non-null String
  static String? alsobad(int x) => 'value: $x';
}
```

## Impact

Any code that wraps a `Map[]` lookup in a function will be falsely flagged.
Map lookups are one of the most common nullable patterns in Dart. This affects
utility classes, configuration lookups, enum-to-string mappings, and localization
helpers.

If developers follow the lint's advice and remove the `?`, the code will either:
1. Fail to compile (if Dart's type system catches the mismatch), or
2. Crash at runtime with a `TypeError` when the key is not found.

# Bug: `avoid_unnecessary_nullable_return_type` false positive on conditional branches with explicit null

## Resolution

**Fixed.** `_NullReturnFinder` and `_expressionCanBeNull` now recursively check `ConditionalExpression` branches, `ParenthesizedExpression`, and `staticType` nullability.

## Summary

The `avoid_unnecessary_nullable_return_type` rule incorrectly flags methods that
return `null` through conditional branches (ternary expressions and if-else
chains) where one branch explicitly evaluates to `null`. The rule claims the
"function never returns null" despite `null` being a reachable return value.

## Severity

**False positive** -- the rule reports that a function never returns null when it
clearly can. Following the lint's advice would either break compilation or
remove intentional API contracts where `null` signals "no result."

## Reproduction

### Minimal example 1: Ternary with null branch

```dart
extension StringExtensions on String {
  // FLAGGED: avoid_unnecessary_nullable_return_type
  //          "Return type is nullable but function never returns null"
  String? encloseInParentheses({bool wrapEmpty = false}) => isEmpty
      ? wrapEmpty
            ? '()'
            : null       // <-- EXPLICIT NULL RETURN
      : '($this)';
}
```

```dart
'hello'.encloseInParentheses();                    // '(hello)'
''.encloseInParentheses(wrapEmpty: true);           // '()'
''.encloseInParentheses(wrapEmpty: false);          // null  ← proven nullable
```

### Minimal example 2: Conditional with null at end

```dart
extension StringExtensions on String {
  // FLAGGED: avoid_unnecessary_nullable_return_type
  String? removeSingleCharacterWords({
    bool trim = true,
    bool removeMultipleSpaces = true,
  }) {
    if (isEmpty) return this;  // non-null (String)
    String result = removeAll(_singleCharWordRegex);
    if (removeMultipleSpaces) {
      result = result.replaceAll(RegExp(r'\s+'), ' ');
    }
    if (trim) {
      result = result.trim();
    }
    return result.isEmpty ? null : result;  // <-- CAN RETURN NULL
  }
}
```

### Minimal example 3: extractCurlyBraces

```dart
extension StringExtensions on String {
  // FLAGGED: avoid_unnecessary_nullable_return_type
  List<String>? extractCurlyBraces() {
    final List<String> matches = _curlyBracesRegex
        .allMatches(this)
        .map((Match m) => m[0])
        .whereType<String>()
        .toList();
    return matches.isEmpty ? null : matches;  // <-- CAN RETURN NULL
  }
}
```

### Lint output

```
line 177 col 3 • [avoid_unnecessary_nullable_return_type] Return type is
nullable but function never returns null. Unnecessary nullability forces
callers to add redundant null checks, reducing code clarity and type
safety. {v3}
```

### All affected locations (4 instances)

| File                                | Line | Method                       | Null return path                                                 |
| ----------------------------------- | ---- | ---------------------------- | ---------------------------------------------------------------- |
| `lib/string/string_extensions.dart` | 177  | `encloseInParentheses`       | `isEmpty && !wrapEmpty` branch returns `null` via nested ternary |
| `lib/string/string_extensions.dart` | 766  | `removeSingleCharacterWords` | `result.isEmpty ? null : result` on line 775                     |
| `lib/string/string_extensions.dart` | 804  | `removeLeadingAndTrailing`   | `value.isEmpty ? null : value` on line 815                       |
| `lib/string/string_extensions.dart` | 953  | `extractCurlyBraces`         | `matches.isEmpty ? null : matches` on line 959                   |

## Root cause

The rule's null-return analysis fails to trace `null` through:

1. **Nested ternary expressions**: When `null` appears in an inner ternary
   branch (e.g., `a ? b ? 'x' : null : 'y'`), the rule does not recognize
   that `null` is a reachable value.

2. **Ternary with null as one operand**: When the pattern is
   `condition ? null : value` or `condition ? value : null`, the rule should
   detect the `NullLiteral` in either branch of the `ConditionalExpression`.

3. **Complex control flow**: When a method has multiple return statements and
   one of them is `return expr ? null : value;`, the rule must check all
   return paths, not just the last or first.

### Likely detection gap

The rule probably searches for top-level `return null;` statements (a
`ReturnStatement` whose expression is a `NullLiteral`). But it misses:

- `return condition ? null : value;` -- the `null` is inside a
  `ConditionalExpression`, not directly in the `ReturnStatement`
- `return a ? b ? null : c : d;` -- the `null` is nested two levels deep
- Expression-bodied functions (`=> expr`) where `null` appears inside `expr`

## Suggested fix

The null-reachability analysis should recursively inspect all expressions
that can contribute to the return value:

```dart
bool canExpressionBeNull(Expression expr) {
  if (expr is NullLiteral) return true;
  if (expr is ConditionalExpression) {
    return canExpressionBeNull(expr.thenExpression) ||
           canExpressionBeNull(expr.elseExpression);
  }

  if (expr is ParenthesizedExpression) {
    return canExpressionBeNull(expr.expression);
  }
  // Also check static type
  final type = expr.staticType;
  if (type != null && type.nullabilitySuffix == NullabilitySuffix.question) {
    return true;
  }

  return false;
}
```

Apply this to every `ReturnStatement.expression` and to expression-bodied
function bodies (`ExpressionFunctionBody.expression`).

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Ternary with null in else branch
String? a(bool cond) => cond ? 'yes' : null;

// Nested ternary with null in inner branch
String? b(bool x, bool y) => x ? y ? 'both' : null : 'neither';

// Conditional return with null
String? c(String s) {
  if (s.isEmpty) return null;
  return s;
}

// Ternary at end of method
List<String>? d(List<String> items) {
  return items.isEmpty ? null : items;
}

// Expression body with nested ternary returning null
int? e(int x) => x > 0 ? x : x == 0 ? null : -x;

// Should STILL flag (true positives, no change):

// All branches return non-null values
String? bad(bool cond) => cond ? 'yes' : 'no';

// All return statements are non-null
String? alsobad(String s) {
  if (s.isEmpty) return '';
  return s.toUpperCase();
}
```

## Impact

Methods that use the `null`-as-sentinel pattern (returning `null` to indicate
"no result" or "empty") are extremely common in Dart utility libraries. This
false positive affects any method where `null` appears inside a ternary
expression or conditional return rather than as a bare `return null;` statement.

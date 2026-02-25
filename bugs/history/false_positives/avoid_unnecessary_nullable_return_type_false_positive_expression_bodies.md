# Bug: `avoid_unnecessary_nullable_return_type` false positive on expression bodies that return null

## Summary

The `avoid_unnecessary_nullable_return_type` rule fires on expression-bodied functions (`=>`) whose return type is correctly nullable. The rule only checks whether the top-level expression is a `NullLiteral`, missing cases where null is returned through conditional expressions, map lookups, or other nullable sub-expressions.

## Severity

**Warning shown on correctly-typed functions.** Following the suggestion to remove `?` from the return type would introduce a compile-time error (expression body type `String?` cannot be assigned to return type `String`) or silently change the function's API contract.

## Reproduction

### Case 1: Ternary with explicit null branch

**File:** `lib/datetime/date_constants.dart` (line 116)

```dart
class MonthUtils {
  static const Map<int, String> monthShortNames = <int, String>{
    1: 'Jan', 2: 'Feb', /* ... */ 12: 'Dec',
  };

  /// Gets the abbreviated name of a month.
  static String? getMonthShortName(int? month) =>
      month == null ? null : monthShortNames[month];
  //         ^^^^            ^^^^^^^^^^^^^^^^^^^^
  //         explicit null    map lookup returns String?
  //                          (null for keys outside 1-12)
}
```

The function returns null in **two** distinct ways:

1. **Explicit null:** when `month == null`, the ternary evaluates to `null`
2. **Map lookup miss:** when `month` is non-null but not in 1-12, `monthShortNames[month]` returns `null`

The rule reports: _"Return type is nullable but function never returns null."_

### Case 2: Map index expression returning nullable

**File:** `lib/datetime/date_constants.dart` (line 113)

```dart
class MonthUtils {
  static const Map<int, String> monthLongNames = <int, String>{
    1: 'January', 2: 'February', /* ... */ 12: 'December',
  };

  /// Gets the full name of a month.
  static String? getMonthLongName(int month) => monthLongNames[month];
  //                                            ^^^^^^^^^^^^^^^^^^
  //                                            Map<int,String>.[] returns String?
}
```

`Map<K, V>.operator[]` returns `V?` (nullable). For any `month` value outside 1-12, this returns `null`. The `String?` return type is correct and necessary.

### Case 3: Same pattern in WeekdayUtils

**File:** `lib/datetime/date_constants.dart` (lines 146, 150)

```dart
class WeekdayUtils {
  static String? getDayLongName(int? dayOfWeek) =>
      dayOfWeek == null ? null : dayLongNames[dayOfWeek];

  static String? getDayShortName(int? dayOfWeek) =>
      dayOfWeek == null ? null : dayShortNames[dayOfWeek];
}
```

Same two patterns: explicit null in ternary + nullable map lookup. All four methods are flagged.

## Diagnostic output

```
info - date_constants.dart:113:10 - [avoid_unnecessary_nullable_return_type] Return type
  is nullable but function never returns null. Unnecessary nullability forces callers to add
  redundant null checks, reducing code clarity and type safety. {v3} Remove the ? from the
  return type. - avoid_unnecessary_nullable_return_type

info - date_constants.dart:116:10 - [avoid_unnecessary_nullable_return_type] Return type
  is nullable but function never returns null. Unnecessary nullability forces callers to add
  redundant null checks, reducing code clarity and type safety. {v3} Remove the ? from the
  return type. - avoid_unnecessary_nullable_return_type
```

(Same for lines 146 and 150.)

## Root cause

**File:** `lib/src/rules/structure_rules.dart` (lines 2260-2278)

The `_canReturnNull()` method handles expression bodies with a single check:

```dart
if (body is ExpressionFunctionBody) {
  return body.expression is NullLiteral;  // <-- Only catches `=> null`
}
```

This only recognizes the trivial case `=> null`. It misses all of the following:

| Expression pattern                          | Returns null? | Detected? |
| ------------------------------------------- | :-----------: | :-------: |
| `=> null`                                   |      Yes      |    Yes    |
| `=> condition ? null : value`               |      Yes      |  **No**   |
| `=> condition ? value : null`               |      Yes      |  **No**   |
| `=> map[key]` (Map operator [])             |      Yes      |  **No**   |
| `=> list.firstOrNull`                       |      Yes      |  **No**   |
| `=> nullableVar`                            |      Yes      |  **No**   |
| `=> someMethod()` where method returns `T?` |      Yes      |  **No**   |

## Suggested fix

### Option A: Check the static type of the expression (recommended)

Instead of pattern-matching AST node types, check whether the expression's static type is nullable:

```dart
if (body is ExpressionFunctionBody) {
  final expressionType = body.expression.staticType;
  if (expressionType != null && expressionType.nullabilitySuffix == NullabilitySuffix.question) {
    return true;  // Expression can produce null
  }

  return body.expression is NullLiteral;
}
```

This catches all cases where the expression evaluates to a nullable type, including map lookups, ternaries with null branches, and nullable method calls.

### Option B: Pattern-match common nullable expressions

If static type information is not reliably available in the custom_lint context, expand the AST pattern matching:

```dart
if (body is ExpressionFunctionBody) {
  return _expressionCanBeNull(body.expression);
}

bool _expressionCanBeNull(Expression expr) {
  // Direct null literal
  if (expr is NullLiteral) return true;

  // Conditional (ternary) with null in either branch
  if (expr is ConditionalExpression) {
    return _expressionCanBeNull(expr.thenExpression) ||
           _expressionCanBeNull(expr.elseExpression);
  }

  // Map/list index access (operator[] returns nullable)
  if (expr is IndexExpression) return true;

  // Null-aware expressions
  if (expr is BinaryExpression && expr.operator.type == TokenType.QUESTION_QUESTION) {
    return true;  // ?? implies LHS can be null
  }

  // Method calls with nullable return type
  final staticType = expr.staticType;
  if (staticType != null && staticType.nullabilitySuffix == NullabilitySuffix.question) {
    return true;
  }

  return false;
}
```

### Option C: Suppress for expression bodies entirely

As a conservative fix, skip expression-bodied functions from this rule. The Dart type system already enforces that expression bodies match the declared return type, so a nullable return type on an expression body is either correct (expression is nullable) or would already be a compile error.

```dart
if (body is ExpressionFunctionBody) {
  return true;  // Trust the developer and Dart's type system
}
```

## Test fixture updates

The fixture file at `example_core/lib/structure/avoid_unnecessary_nullable_return_type_fixture.dart` should add cases that must NOT trigger the lint:

```dart
// GOOD: Ternary with null branch — nullable return type is required
String? ternaryWithNull(int? value) => value == null ? null : value.toString();

// GOOD: Map lookup — operator[] returns nullable
String? mapLookup(int key) => const <int, String>{1: 'a', 2: 'b'}[key];

// GOOD: Ternary with null branch AND nullable sub-expression
String? ternaryWithMapLookup(int? key) =>
    key == null ? null : const <int, String>{1: 'a'}[key];

// GOOD: Nullable variable in expression body
String? nullablePassthrough(String? input) => input;

// GOOD: Method returning nullable
String? tryParseWrapper(String s) => int.tryParse(s)?.toString();
```

## Resolution

**Fixed 2026-02-22.** Root cause confirmed in `structure_rules.dart`. The `_canReturnNull()` method only checked `body.expression is NullLiteral`. Added `_expressionCanBeNull()` which recursively checks ternary branches for null literals and checks the expression's `staticType` for `NullabilitySuffix.question`. This covers map lookups, nullable variables, nullable method returns, and all other nullable expression patterns.

## Environment

- **OS:** Windows 11 Pro 10.0.22631
- **IDE:** VS Code
- **Rule version:** v3
- **saropa_lints version:** (current)
- **Dart SDK:** (current stable)

# Task: `prefer_interpolation_to_compose`

## Summary
- **Rule Name**: `prefer_interpolation_to_compose`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Style

## Problem Statement
String concatenation using the `+` operator is harder to read than string interpolation when mixing string literals with variable expressions. Compare:

```dart
// Concatenation — requires tracking open/close quotes and operators
final greeting = 'Hello, ' + firstName + ' ' + lastName + '!';

// Interpolation — reads as a single coherent string
final greeting = 'Hello, $firstName $lastName!';
```

The concatenation form:
1. **Introduces visual noise** from repeated quotes and `+` operators
2. **Creates runtime allocations** for each intermediate string (the Dart VM cannot always optimize away intermediate strings from `+` chains)
3. **Is error-prone** for forgetting spaces: `'Hello,' + name` vs `'Hello, ' + name`
4. **Is inconsistent** with Dart style guide which explicitly recommends interpolation

This rule flags `+` on strings where at least one operand is a string literal, which is the case where interpolation can definitively replace concatenation.

## Description (from ROADMAP)
Detects string concatenation using `+` where at least one operand is a string literal, recommending string interpolation instead.

## Trigger Conditions
- A `BinaryExpression` with operator `+`
- The static type of the binary expression is `String`
- At least one of the operands (`leftOperand` or `rightOperand`) is a `StringLiteral` (simple, interpolated, or adjacent string)
- The expression is not inside a `const` context (where `+` is not valid anyway, but defensive check)

## Implementation Approach

### AST Visitor
```dart
context.registry.addBinaryExpression((node) {
  // ...
});
```

### Detection Logic
1. Check `node.operator.type == TokenType.PLUS`.
2. Resolve the static type of `node`: confirm it is `String` (use `node.staticType?.isDartCoreString ?? false`).
3. Check whether `node.leftOperand` is a `StringLiteral` OR `node.rightOperand` is a `StringLiteral`.
4. A `StringLiteral` includes: `SimpleStringLiteral`, `StringInterpolation`, and `AdjacentStrings`.
5. Walk up the parent chain to detect chained concatenations (e.g., `'a' + b + 'c'` is a tree of two `BinaryExpression` nodes). Report only the outermost node to avoid double-reporting each sub-expression.
6. Skip if the parent is itself a `BinaryExpression` with operator `+` and the same string type — this means the current node is an inner node of a chain; let the outer node be reported.

### Chain Detection (Avoid Double-Reporting)
```dart
bool _isInnerNodeOfChain(BinaryExpression node) {
  final parent = node.parent;
  return parent is BinaryExpression &&
      parent.operator.type == TokenType.PLUS &&
      (parent.staticType?.isDartCoreString ?? false);
}
```

## Code Examples

### Bad (triggers rule)
```dart
// Simple concatenation with a literal.
final greeting = 'Hello, ' + name + '!'; // LINT

// Concatenation with only one literal side.
final path = base + '/api/v1'; // LINT

// Chained concatenation — report the whole chain once.
final msg = 'User ' + userId + ' logged in at ' + timestamp; // LINT

// Concatenation in argument.
print('Value: ' + value.toString()); // LINT

// Concatenation in return.
String label() => prefix + ': ' + description; // LINT
```

### Good (compliant)
```dart
// Use interpolation instead.
final greeting = 'Hello, $name!';
final path = '$base/api/v1';
final msg = 'User $userId logged in at $timestamp';

// For complex expressions, use ${}:
print('Value: ${value.toString()}');
String label() => '$prefix: $description';

// Two non-literal variables concatenated — interpolation still helps but
// this case is less clear-cut. Consider flagging separately.
final a = x + y; // If both are String variables — may still prefer interpolation

// String + non-String — not string concatenation, skip.
final n = 1 + 2;

// Concatenation of only literals — see prefer_adjacent_strings rule.
final sql = 'SELECT * ' + 'FROM users'; // Handled by prefer_adjacent_strings

// Explicit toString call for non-string in const context:
// const doesn't allow + between String and non-String anyway.
```

## Edge Cases & False Positives
- **Both operands are literals**: `'foo' + 'bar'` — this is better handled by `prefer_adjacent_strings` (use `'foo' 'bar'`). Consider not flagging this case in this rule to avoid overlap, and document the companion rule.
- **Concatenation in `const` context**: Dart allows `const String s = 'a' + 'b'` (literal concatenation is const). This is already better expressed as adjacent strings. Skip or let `prefer_adjacent_strings` handle it.
- **`toString()` calls**: `obj.toString() + ' suffix'` — the `toString()` result is not a literal, but the `' suffix'` is. Flag this and suggest `'${obj} suffix'` or `'${obj.toString()} suffix'`.
- **Buffer pattern**: Building strings in a loop with `+=` (i.e., `result += item`) is a common pattern where `StringBuffer` is more efficient. This is a different concern — do not flag loop-based `+=` concatenation in this rule (it is a performance rule, not a style rule).
- **Localization strings**: Strings from `AppLocalizations` (l10n) are often concatenated because interpolation changes the structure of the localization key. Exercise caution here — consider skipping expressions where one operand is a method call on an l10n object.
- **SQL strings**: Multi-line SQL strings assembled with `+` may be more readable than a single interpolated string. Consider a suppression comment pattern.
- **Generated code**: Skip `*.g.dart` files.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: literal on left
String t1(String name) => 'Hello, ' + name; // LINT

// Test 2: literal on right
String t2(String base) => base + '/path'; // LINT

// Test 3: both sides — flag once
String t3(String a, String b) => 'start ' + a + ' middle ' + b + ' end'; // LINT

// Test 4: concatenation as argument
void t4(String name) => print('Name: ' + name); // LINT
```

### Should NOT Trigger (compliant)
```dart
// Test 5: already using interpolation
String t5(String name) => 'Hello, $name';

// Test 6: non-string addition
int t6(int a, int b) => a + b;

// Test 7: both sides are non-literal strings
String t7(String a, String b) => a + b; // No literal — consider a separate rule

// Test 8: adjacent string literals — different rule
const String t8 = 'foo' 'bar';
```

## Quick Fix
**Message**: "Replace string concatenation with string interpolation"

The fix for a chain `'literal' + expr + ' more'` should:
1. Identify the outermost `BinaryExpression` in the `+` chain.
2. Recursively flatten the chain into segments: each segment is either a string literal value or an expression.
3. Merge consecutive literal segments.
4. Wrap non-literal expressions with `${}` interpolation (use `$varName` if the expression is a simple identifier, `${expr}` for complex expressions).
5. Produce a single `StringInterpolation` node that combines all segments.

Example transformation:
```dart
// Before:
'Hello, ' + firstName + ' ' + lastName + '!'
// After:
'Hello, $firstName $lastName!'
```

## Notes & Issues
- Dart's official linter includes `prefer_interpolation_to_compose_strings` — review that implementation for known edge cases and reference the rule name in documentation.
- The quick fix for complex chains is non-trivial to implement correctly — it must handle quote styles, escape sequences in literal segments, and expression complexity. Budget accordingly.
- The rule should be documented as complementary to `prefer_adjacent_strings` — together they form a complete string composition policy.
- The correction message should cite the Dart style guide section on string interpolation.

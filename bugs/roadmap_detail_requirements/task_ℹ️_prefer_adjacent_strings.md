# Task: `prefer_adjacent_strings`

## Summary
- **Rule Name**: `prefer_adjacent_strings`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Style

## Problem Statement
When two string _literals_ are concatenated using the `+` operator, the result is computed at compile time but still expressed as a runtime operation. Dart (like C) supports adjacent string literals — two or more string literals placed next to each other are automatically merged by the compiler at compile time:

```dart
// + operator — looks like runtime work, is actually compile-time
final sql = 'SELECT id, name ' + 'FROM users WHERE active = 1';

// Adjacent strings — clearly compile-time, no operator noise
final sql = 'SELECT id, name '
            'FROM users WHERE active = 1';
```

Beyond correctness, adjacent strings:
1. **Are more readable for multi-line strings** — each part is on its own line without `+` visual noise
2. **Signal compile-time composition** clearly — readers immediately know no runtime work happens
3. **Allow mixing raw and regular strings** — `r'\n' '\n'` concatenates a raw and regular string literal at compile time
4. **Are the idiomatic Dart pattern** documented in the style guide

## Description (from ROADMAP)
Detects `+` concatenation of two string literals, recommending the adjacent string literal syntax for compile-time composition.

## Trigger Conditions
- A `BinaryExpression` with operator `+`
- The static type of the expression is `String`
- Both the `leftOperand` AND `rightOperand` are `StringLiteral` nodes (either `SimpleStringLiteral` or `AdjacentStrings`)
- Neither operand contains interpolation (i.e., neither is a `StringInterpolation`) — pure literals only

## Implementation Approach

### AST Visitor
```dart
context.registry.addBinaryExpression((node) {
  // ...
});
```

### Detection Logic
1. Check `node.operator.type == TokenType.PLUS`.
2. Confirm the static type of `node` is `String`.
3. Check `node.leftOperand is SimpleStringLiteral || node.leftOperand is AdjacentStrings`.
4. Check `node.rightOperand is SimpleStringLiteral || node.rightOperand is AdjacentStrings`.
5. Exclude `StringInterpolation` nodes — they contain expressions and cannot be adjacent in the same way (though technically Dart does support adjacent interpolated strings, the simpler case is clearer).
6. Check for chain: if the parent is also a `+` BinaryExpression of strings, skip and let the parent be reported (to avoid reporting each sub-expression in `'a' + 'b' + 'c'`).

### String Literal Type Check Helper
```dart
bool _isPureLiteral(Expression expr) =>
    expr is SimpleStringLiteral || expr is AdjacentStrings;
```

## Code Examples

### Bad (triggers rule)
```dart
// Two literals joined with +
final sql = 'SELECT * ' + 'FROM users'; // LINT

// Long SQL split across multiple lines with +
final query = 'SELECT id, name, email ' +
    'FROM users ' +
    'WHERE active = 1 ' +
    'ORDER BY name'; // LINT (chain)

// URL assembly from literals
final url = 'https://api.example.com' + '/v1/users'; // LINT

// Const context — const strings cannot use + at all (compile error),
// but non-const + is flagged.
final prefix = 'app_' + 'debug_'; // LINT
```

### Good (compliant)
```dart
// Adjacent strings — compiler merges at compile time.
final sql = 'SELECT * '
    'FROM users';

// Multi-line query — very readable.
final query = 'SELECT id, name, email '
    'FROM users '
    'WHERE active = 1 '
    'ORDER BY name';

// URL with adjacent strings.
final url = 'https://api.example.com'
    '/v1/users';

// Mixing raw and regular strings — only possible with adjacent syntax.
final pattern = r'\d+' '.0';

// Concatenation with a variable — not flagged by this rule (see prefer_interpolation_to_compose).
final path = basePath + '/api';

// Interpolated string — not a pure literal, different rule applies.
final greeting = 'Hello $name' + ' welcome'; // Handled by prefer_interpolation_to_compose
```

## Edge Cases & False Positives
- **`const` context**: Dart does not allow `+` between strings in `const` context — this produces a compile error, so it will never appear in valid code. No special handling needed.
- **Adjacent strings with interpolation**: Dart allows adjacent strings where some are interpolated: `'Hello $name' ' world'`. This is unusual but valid. The rule targets only pure literals (`SimpleStringLiteral` and `AdjacentStrings`), not `StringInterpolation`.
- **Mixed raw and regular strings**: `r'\path\to' + 'file'` — both are literals, flag and suggest adjacent form `r'\path\to' 'file'`. The fix must be careful about string type mixing.
- **Chained concatenation of literals**: `'a' + 'b' + 'c'` — this is two nested `BinaryExpression` nodes. Report only the outermost, and the fix should collapse the entire chain into one adjacent string expression.
- **String in a list**: `['prefix_' + 'suffix']` — still a literal + literal concatenation, flag it.
- **String assigned to `const`**: `const x = 'a' + 'b'` — actually, `const` string concatenation with `+` IS valid in Dart and computes at compile time. However, adjacent strings are still cleaner. Flag this case too.
- **Generated code**: Skip `*.g.dart`, `*.freezed.dart`.
- **Very long single-line strings**: Strings that are genuinely multi-line via `+` for readability should remain flagged — adjacent strings with line breaks are the proper solution.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: simple two-literal concatenation
const String t1 = 'foo' + 'bar'; // LINT? check const rules
final String t2 = 'foo' + 'bar'; // LINT

// Test 2: chained literal concatenation
final String t3 = 'SELECT ' + 'id ' + 'FROM t'; // LINT

// Test 3: URL from literals
final String t4 = 'https://example.com' + '/api'; // LINT
```

### Should NOT Trigger (compliant)
```dart
// Test 4: adjacent strings already
final String t5 = 'foo' 'bar';

// Test 5: one side is a variable
final String t6 = 'prefix_' + variableName; // Not flagged — different rule

// Test 6: non-string addition
final int t7 = 1 + 2;

// Test 7: interpolated string involved
final String t8 = 'Hello $name' + ' world'; // Different rule
```

## Quick Fix
**Message**: "Use adjacent string literals instead of + concatenation"

The fix for a chain `'a' + 'b' + 'c'` should:
1. Identify all literal segments in the `+` chain by flattening the nested `BinaryExpression` tree.
2. Remove all `+` operators and any surrounding whitespace/newlines between the literals.
3. Output the segments as adjacent string literals, separated by whitespace (optionally formatted across lines if the result would be long).

Example transformation:
```dart
// Before:
final sql = 'SELECT id, name ' +
    'FROM users ' +
    'WHERE active = 1';

// After:
final sql = 'SELECT id, name '
    'FROM users '
    'WHERE active = 1';
```

Special case — mixing quote styles:
```dart
// Before:
final x = 'it\'s ' + "a test";
// After:
final x = "it's " "a test";
// or:
final x = 'it\'s ' 'a test';
// Choose the quote style that minimizes escaping.
```

## Notes & Issues
- This rule is closely related to `prefer_interpolation_to_compose` — together they form a complete policy on string composition. The relationship should be documented: use `prefer_adjacent_strings` for literal-only concatenation and `prefer_interpolation_to_compose` for mixed literal+expression concatenation.
- Dart's official linter includes `prefer_adjacent_string_literals` — review that implementation. The rule is straightforward but the fix for chains requires recursive tree flattening.
- The Stylistic tier could also be appropriate — this is a style preference with no performance implication for pure literals in non-const context (the VM interns identical strings). However, the compile-time clarity argument justifies Recommended.
- The correction message should include a link to the Dart style guide section on strings.

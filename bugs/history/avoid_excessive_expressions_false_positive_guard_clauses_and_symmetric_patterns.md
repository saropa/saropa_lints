# Bug: `avoid_excessive_expressions` false positive on guard clauses and symmetric structural patterns

## Resolution

**Fixed.** Guard clauses (if + return/throw) now have elevated threshold (10 operators). Symmetric structural patterns (3+ groups with same operator shape) are fully exempt.


## Summary

The `avoid_excessive_expressions` rule flags expressions with >5 operators
regardless of their structural pattern. Two common idioms produce false
positives because their operator count is high but their cognitive complexity
is low:

1. **Guard clauses** (early-return `if` statements) with multiple simple
   conditions joined by `||`
2. **Symmetric structural patterns** where the same operator pair is repeated
   in parallel (e.g., `startsWith && endsWith` for multiple bracket types)

Both patterns are universally recommended in Dart style guides and have low
cognitive complexity despite high operator counts.

## Severity

**False positive** -- the rule penalizes well-structured, readable code.
Guard clauses are explicitly recommended by the Dart style guide ("prefer
early returns") and by the project's own rules ("guards early"). Symmetric
patterns are a natural encoding of lookup-table-style logic.

## Reproduction

### Example 1: Guard clause with multiple conditions

```dart
String truncateWithEllipsisPreserveWords(int? cutoff) {
  final int charLength = characters.length;

  // FLAGGED: avoid_excessive_expressions (>5 operators)
  //          6 operators: ||, ==, ||, <=, ||, <=
  if (isEmpty || cutoff == null || cutoff <= 0 || charLength <= cutoff) {
    return this;
  }
  // ... rest of method
}
```

This is a standard **guard clause** — an early return that rejects invalid
inputs before the method's real logic begins. Each condition is trivially
simple (one comparison each). The `||` chain reads as a checklist:
"if empty, or no cutoff, or cutoff invalid, or already short enough → return."

### Example 2: Symmetric bracket-matching pattern

```dart
bool isBracketWrapped() {
  if (length < 2) return false;

  // FLAGGED: avoid_excessive_expressions (>5 operators)
  //          7 operators: && || && || && || &&
  return (startsWith('(') && endsWith(')')) ||
      (startsWith('[') && endsWith(']')) ||
      (startsWith('{') && endsWith('}')) ||
      (startsWith('<') && endsWith('>'));
}
```

This is a **symmetric structural pattern** — four identical `startsWith &&
endsWith` pairs joined by `||`. Each line has the exact same shape. A
developer reads ONE line and understands all four. The cognitive complexity
is closer to 2 (one pair + "repeated for other bracket types") than 7.

### Lint output

```
line 225 col 9 • [avoid_excessive_expressions] Expression has excessive
complexity (>5 operators). Complex expressions are hard to read and
maintain. This excessive complexity makes the code harder to understand,
test, and maintain. {v4}
```

### All affected locations (2 instances)

| File | Line | Pattern | Operators | Cognitive complexity |
|------|------|---------|-----------|---------------------|
| `lib/string/string_extensions.dart` | 225 | Guard clause (`\|\|` chain) | 6 | Low — linear checklist |
| `lib/string/string_extensions.dart` | 575-578 | Symmetric pairs (`&& \|\|`) | 7 | Low — one pattern × 4 |

## Root cause

The rule counts operators without considering:

1. **Expression structure**: A flat `||` chain of simple comparisons has lower
   cognitive complexity than nested/mixed operators at the same count.

2. **Guard clause context**: When the `if` body is just `return` or `throw`,
   the expression is a guard — a filter that the reader mentally skips once
   understood. The main logic follows after.

3. **Structural repetition**: When the same sub-expression pattern repeats
   (`A && B || C && D || E && F`), each repetition adds minimal cognitive
   load because the reader recognizes the pattern from the first occurrence.

## Suggested fix

### Option A: Exempt guard clauses

If the expression is inside an `if` statement whose body only contains a
`return` or `throw` statement, raise the threshold or skip entirely:

```dart
void checkExpression(Expression expr) {
  final operatorCount = countOperators(expr);
  if (operatorCount <= 5) return;

  // Check if this is a guard clause (if + return/throw)
  final parent = expr.parent;
  if (parent is IfStatement) {
    final thenBody = parent.thenStatement;
    if (thenBody is ReturnStatement || thenBody is ExpressionStatement) {
      // Guard clause — use higher threshold (e.g., 10)
      if (operatorCount <= 10) return;
    }
  }

  // ... flag as usual
}
```

### Option B: Discount repeated structural patterns

Count the number of **distinct operator patterns** rather than raw operator
count. For `(A && B) || (C && D) || (E && F) || (G && H)`:

- Distinct patterns: `_ && _` (1) and `_ || _` (1) = 2
- Raw operators: 7

Use the distinct pattern count or a weighted score that discounts repetition.

### Option C: Use cognitive complexity instead of operator count

Replace raw operator counting with a cognitive complexity metric that accounts
for nesting depth, not just count:

| Expression | Operators | Cognitive complexity |
|-----------|-----------|---------------------|
| `a \|\| b \|\| c \|\| d` | 3 | 1 (flat chain) |
| `a && (b \|\| (c && d))` | 3 | 3 (nested) |
| `(a && b) \|\| (c && d) \|\| (e && f) \|\| (g && h)` | 7 | 2 (one pattern, repeated) |

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Guard clause with multiple simple conditions
void guardClause(int? x, int? y) {
  if (x == null || y == null || x <= 0 || y <= 0 || x > 100 || y > 100) {
    return;  // Guard: early return
  }
  // ... main logic
}

// Symmetric bracket/wrapper check
bool isWrapped(String s) {
  return (s.startsWith('(') && s.endsWith(')')) ||
      (s.startsWith('[') && s.endsWith(']')) ||
      (s.startsWith('{') && s.endsWith('}'));
}

// Flat OR chain of equality checks
bool isVowel(String c) {
  return c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u';
}

// Should STILL flag (true positives, no change):

// Deeply nested mixed operators
bool complex(int a, int b, int c) {
  return a > 0 && (b < 0 || (c != 0 && a + b > c - 1) || b * c < a);
}

// Mixed operator types with no structural repetition
bool messy(String s, int n, bool f) {
  return s.isNotEmpty && n > 0 || f && s.length < n && !s.contains(' ');
}
```

## Impact

Guard clauses are the single most recommended refactoring pattern in Dart and
across programming languages. The project's own CLAUDE.md rules section says
"Guards Early" with an example. This rule penalizes the exact pattern the
project encourages.

Symmetric structural patterns are the clearest way to express lookup-table
logic inline. Extracting them into named variables (as the rule suggests)
can actually reduce readability by separating the pattern from its context.

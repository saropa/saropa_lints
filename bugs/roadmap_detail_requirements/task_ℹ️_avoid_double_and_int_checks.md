# Task: `avoid_double_and_int_checks`

## Summary
- **Rule Name**: `avoid_double_and_int_checks`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
In Dart's type system, `int` and `double` are both subtypes of `num`, but they are
disjoint from each other — no value can simultaneously be both an `int` and a `double`.
Therefore:

- `value is int && value is double` is **always false** (logical impossibility).
- `value is int || value is double` is **always equivalent to** `value is num`
  (verbose and potentially misleading).

Developers sometimes write these combined type checks out of uncertainty about the
relationship between `int` and `double`, especially when porting code from languages
where numeric types have different relationships (e.g., JavaScript where all numbers
are IEEE 754 doubles). The combined check adds confusion and signals a misunderstanding
of Dart's type hierarchy.

## Description (from ROADMAP)
Flag combined `is int && is double` (always false) or `is int || is double` (use `is num`)
type checks on the same expression.

## Trigger Conditions

**Pattern A (always false):**
1. A `BinaryExpression` with `&&` operator.
2. Both operands are `IsExpression` nodes targeting the same variable/expression.
3. One `IsExpression` checks `is int`, the other checks `is double`.

**Pattern B (use `is num` instead):**
1. A `BinaryExpression` with `||` operator.
2. Both operands are `IsExpression` nodes targeting the same variable/expression.
3. One checks `is int`, the other checks `is double`.

Also handle the negated forms: `is! int || is! double` (always true, redundant) and
chained forms in more complex boolean trees.

## Implementation Approach

### AST Visitor
```dart
context.registry.addBinaryExpression((node) { ... });
```

### Detection Logic
1. Check `node.operator.type` is `TokenType.AMPERSAND_AMPERSAND` or
   `TokenType.BAR_BAR`.
2. Extract `left` and `right` operands.
3. Both must be `IsExpression` nodes (handle `is` and `is!` separately).
4. For each `IsExpression`, check the `type` clause:
   - Is it a `NamedType` whose `name.name` is `'int'`?
   - Is it a `NamedType` whose `name.name` is `'double'`?
   - Do both `IsExpression` nodes have the same `notOperator` (both `is` or both `is!`)?
5. Verify both expressions share the same target expression. For `SimpleIdentifier`
   targets, compare the resolved `staticElement`. For more complex expressions, compare
   source text as a fallback (conservative).
6. If all conditions hold:
   - For `&&` with both `is`: report "condition is always false" (int and double are disjoint).
   - For `||` with both `is`: report "prefer `is num`" (simpler and more explicit).
   - For `&&` with both `is!`: report "condition is always true" (redundant).
   - For `||` with both `is!`: skip or handle separately.

## Code Examples

### Bad (triggers rule)
```dart
void process(Object value) {
  // Always false — int and double are disjoint
  if (value is int && value is double) {
    print('impossible');
  }
}

bool isNumeric(Object value) {
  // Should use: value is num
  return value is int || value is double;
}

void check(dynamic x) {
  // Verbose and confusing — same as x is num
  final isNumber = x is double || x is int;
}
```

### Good (compliant)
```dart
void process(Object value) {
  // Correct: check for num
  if (value is num) {
    print('is a number');
  }
}

bool isNumeric(Object value) => value is num;

// Separate checks are fine when the logic differs per type
void handleNumber(num value) {
  if (value is int) {
    print('integer: $value');
  } else if (value is double) {
    print('double: $value');
  }
}
```

## Edge Cases & False Positives
- **Different variables**: `if (a is int && b is double)` — two different identifiers;
  do not flag.
- **Nullable variants**: `value is int?` and `value is double?` — both nullable numeric
  types. The rule still applies: `is int? || is double?` is equivalent to `is num?`.
  Flag with appropriate message adjustment.
- **Complex target expressions**: `items[index] is int && items[index] is double` —
  `items[index]` may have side effects; do not assume same value. Skip (conservative).
- **Chained conditions**: `a is int && b is String && a is double` — detect the pair
  `a is int && a is double` even when mixed with other conditions.
- **Pattern matching (Dart 3)**: `switch` expressions and `if-case` patterns use different
  AST nodes. The initial implementation can target `BinaryExpression` only; Dart 3
  pattern matching is a follow-up.
- **Negated forms**: `value is! int && value is! double` is always true (everything that
  is not int and not double covers most objects) — technically redundant but semantically
  meaningful if the intent is "is neither int nor double". Do not flag this form.
- **Type aliases**: If `typedef MyInt = int;`, then `is MyInt` should be treated the
  same as `is int`. The resolved element comparison handles this.
- **`num` subclasses in other packages**: Custom `num` subclasses are not `int` or
  `double`. The rule only targets the core `dart:core` `int` and `double` types.
  Use element equality checks against the core library elements, not name string matching.

## Unit Tests

### Should Trigger (violations)
```dart
void test1(Object v) {
  if (v is int && v is double) {       // LINT: always false
    print('never');
  }
}

bool test2(Object v) =>
    v is int || v is double;           // LINT: use is num

void test3(dynamic x) {
  final check = x is double || x is int;  // LINT: use is num
  print(check);
}
```

### Should NOT Trigger (compliant)
```dart
// ok: separate variables
void test4(Object a, Object b) {
  if (a is int && b is double) print('different vars');
}

// ok: already uses num
bool test5(Object v) => v is num;

// ok: separate if-else (correct usage)
void test6(num n) {
  if (n is int) {
    print('int');
  } else if (n is double) {
    print('double');
  }
}

// ok: negated mixed forms — skip
void test7(Object v) {
  if (v is! int && v is! double) print('not a number');
}
```

## Quick Fix

**For `&&` (always false):** Suggest removing the entire condition or replacing the
block with a comment noting it is dead code.

**For `||` (use `is num`):** Replace `value is int || value is double` with `value is num`.

```dart
// Before
return value is int || value is double;

// After
return value is num;
```

For the `&&` case, the fix removes the always-false block:
```dart
// Before
if (value is int && value is double) {
  doSomething();
}

// After
(statement removed — dead code)
```

## Notes & Issues
- The core insight here is type-hierarchy knowledge that the general Dart analyzer does
  not flag by default. This is a value-add rule for saropa_lints.
- Use `typeSystem.isSubtypeOf` from the analyzer API to verify that `int` and `double`
  are disjoint, rather than hardcoding names. This makes the rule robust against any
  future changes (unlikely but correct practice).
- In practice, the `||` form (prefer `is num`) is far more common than the `&&` form
  (always false). Prioritize detecting and fixing the `||` form first.
- The rule name `avoid_double_and_int_checks` should have a companion message in the
  `&&` case that clearly says "this condition is always false because int and double are
  disjoint types" and in the `||` case "prefer `is num` which is equivalent and clearer."

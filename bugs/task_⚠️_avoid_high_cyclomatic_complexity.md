# Task: `avoid_high_cyclomatic_complexity`

## Summary
- **Rule Name**: `avoid_high_cyclomatic_complexity`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.61 Code Quality Rules

## Problem Statement

Cyclomatic complexity measures the number of linearly independent paths through a function. A function with complexity > 10 is hard to:
1. **Understand** — too many branches to hold in working memory
2. **Test** — N paths need N test cases for full branch coverage
3. **Refactor** — high coupling between branches
4. **Maintain** — bugs hide in rarely-executed paths

Common sources of high complexity: nested if/else chains, long switch statements, deeply nested loops with conditions.

## Description (from ROADMAP)

> Warn when functions exceed a configurable cyclomatic complexity threshold.

## Complexity Calculation

McCabe's cyclomatic complexity = number of decision points + 1:
- `if` statement: +1
- `else if` clause: +1 (each)
- `for` / `while` / `do-while`: +1 each
- `catch` clause: +1
- `&&` / `||` in conditions: +1 each (modified cyclomatic complexity)
- `?:` ternary: +1
- `switch case` (each case): +1
- Null-aware `??`: +1

Default threshold: 10 (configurable)

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addFunctionDeclaration((node) {
  final complexity = _calculateComplexity(node.functionExpression.body);
  if (complexity > _threshold) {
    reporter.atNode(node.name, _createCode(complexity));
  }
});

context.registry.addMethodDeclaration((node) {
  final complexity = _calculateComplexity(node.body);
  if (complexity > _threshold) {
    reporter.atNode(node.name, _createCode(complexity));
  }
});
```

### Complexity Calculator

```dart
int _calculateComplexity(FunctionBody? body) {
  if (body == null) return 1;
  final visitor = _ComplexityVisitor();
  body.accept(visitor);
  return visitor.complexity + 1;  // +1 for the function itself
}

class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 0;

  @override
  void visitIfStatement(IfStatement node) {
    complexity++;
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    complexity++;
    super.visitForStatement(node);
  }
  // etc.
}
```

### Configuration
```yaml
custom_lint:
  rules:
    avoid_high_cyclomatic_complexity:
      max_complexity: 10  # default
      count_logical_operators: true  # count && and ||
```

## Code Examples

### Bad (Should trigger with complexity > 10)
```dart
// Complexity ≈ 12: many branches
String processOrder(Order order) {  // ← trigger
  if (order == null) return 'invalid';
  if (order.status == 'pending') {
    if (order.paymentMethod == 'card') {
      if (order.amount > 1000) {
        return 'high-value pending card';
      } else {
        return 'normal pending card';
      }
    } else if (order.paymentMethod == 'cash') {
      return 'pending cash';
    }
  } else if (order.status == 'processing') {
    for (final item in order.items) {
      if (item.inStock && item.price > 0) {
        process(item);
      }
    }
    return 'processing';
  } else if (order.status == 'shipped') {
    return order.express ? 'express shipped' : 'standard shipped';
  }
  return 'unknown';
}
```

### Good (Should NOT trigger)
```dart
// Refactored to smaller methods
String processOrder(Order order) {
  if (order == null) return 'invalid';
  return switch (order.status) {
    'pending' => _processPending(order),
    'processing' => _processProcessing(order),
    'shipped' => _processShipped(order),
    _ => 'unknown',
  };
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Generated code (`.g.dart`) | **Suppress** — generated code can be complex | |
| `switch` on sealed class (exhaustive) | **Count each case** — but exhaustive switches are acceptable | May need to not count sealed switch cases |
| `build()` method in Flutter widgets | **Trigger but note** — Flutter `build()` methods are often complex due to widget tree | May want separate threshold for `build()` |
| Test methods with many assertions | **Trigger** — but test methods with many branches should also be refactored | |
| Setter methods | **Count** — setters with validation logic can be complex | |
| Abstract method | **Suppress** — no body | |
| Getters with complex expressions | **Count** — getters can have complex logic | |

## Unit Tests

### Violations
1. Function with 11 decision points → 1 lint with complexity value
2. Method with deeply nested if/else → 1 lint
3. Switch with 12 cases (each +1) → 1 lint

### Non-Violations
1. Function with 5 decision points → no lint
2. Generated file → no lint
3. Abstract method → no lint

## Quick Fix

No automated fix — reducing complexity requires manual refactoring.

The problem message should include the actual complexity count:
```
[avoid_high_cyclomatic_complexity] Function 'processOrder' has cyclomatic complexity of 12, exceeding the threshold of 10. Refactor into smaller methods.
```

## Notes & Issues

1. **Problem message must include the complexity number** — without the number, the developer can't assess how much refactoring is needed.
2. **The threshold should be configurable** — different teams have different standards. Default of 10 is widely accepted.
3. **Flutter `build()` methods** are notoriously complex but are often hard to break down further. A separate (higher) threshold for `build()` methods may be useful.
4. **`dart_code_metrics`** already has a cyclomatic complexity rule. Verify our implementation matches their results before releasing. If the project already uses `dart_code_metrics`, suppress to avoid duplicate reporting.
5. **Modified vs. Classic McCabe**: Classic McCabe counts branching nodes only; Modified McCabe also counts `&&`/`||`. The configurable option `count_logical_operators` handles this.

# Task: `avoid_unused_local_variable`

## Summary
- **Rule Name**: `avoid_unused_local_variable`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.61 Code Quality Rules

## Problem Statement

Local variables that are declared but never read waste memory (minor) and more importantly signal one of:
1. **Incomplete implementation**: The variable was intended for use but the code was never finished
2. **Dead code**: A refactoring removed the usage but not the declaration
3. **Bug**: The variable was intended to be used but a different variable name was used by mistake

Dart's existing `unused_local_variable` hint already flags these, but at INFO/hint severity. This rule provides WARNING severity.

## Description (from ROADMAP)

> Local variables that are declared but never used.

## Trigger Conditions

1. A local variable is declared with `var`, `final`, `const`, or explicit type
2. The variable is never read in the scope it was declared
3. The variable is not `_` (a discard variable) or named with underscore prefix to indicate discard intent

## Implementation Approach

### Overlap with Built-in Rule
**IMPORTANT**: Dart's built-in `unused_local_variable` already exists. Check if it can be configured to WARNING severity. If it can, this rule is redundant.

### AST Visitor Pattern (if custom rule needed)

```dart
context.registry.addVariableDeclaration((node) {
  final element = node.declaredElement;
  if (element == null) return;
  if (element.name.startsWith('_')) return;  // discard intent
  if (element.name == '_') return;
  // Check if the variable is ever referenced
  // This requires looking at all SimpleIdentifier nodes in the scope
  // and checking if any reference this element
});
```

**Note**: Detecting "never used" requires scope analysis. The `custom_lint` AST visitor model may not provide the efficient scope analysis needed. Consider using `context.addPostRunCallback` to check all variables after visiting the full compilation unit.

## Code Examples

### Bad (Should trigger)
```dart
void processData(List<int> items) {
  final sorted = items.sorted();  // ← trigger: sorted is never used
  for (final item in items) {  // uses original, not sorted
    process(item);
  }
}

// Variable set but never read
int count = 0;
for (final item in items) {
  count++;  // ← trigger: count is incremented but never read
  process(item);
}
```

### Good (Should NOT trigger)
```dart
// Variable IS used
void processData(List<int> items) {
  final sorted = items.sorted();
  for (final item in sorted) {  // ✓ sorted is used
    process(item);
  }
}

// Underscore discard ✓
for (final _ in items) {
  totalCount++;
}

// Loop variable in for-in ✓ (even if only side effects needed)
for (final entry in map.entries) {
  print(entry.value);  // ✓ entry is used
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Variable used only in a nested function that is never called | **Trigger** — transitive non-use | Complex to detect |
| Variable reassigned but original value unused | **Trigger** — initial assignment wasted | |
| `var _ = sideEffectFunction()` | **Suppress** — explicit discard | |
| Variable used via `debugPrint` only | **Suppress** — debug use is use | |
| Variable captures a resource that must be disposed | **Trigger** (resource leaked) | But resource leak is a separate rule |
| Pattern matching variable | **Suppress if it's a pattern match** — `final int(:x, :y) = point;` | |
| Late variable declared but not initialized | **Different rule** — `avoid_unassigned_late_fields` | |
| `for (final item in list)` where `item` not used in body | **Trigger** — use `for (int i = 0; i < list.length; i++)` or `_` | |
| Variable used only for type assertion | **Suppress** — type check via variable IS a use | |

## Unit Tests

### Violations
1. `final x = compute(); print('done');` where `x` never read → 1 lint
2. `int count = 0; count++; return result;` where count never read → 1 lint

### Non-Violations
1. `final x = compute(); return x;` → no lint
2. `final _ = riskyOperation();` → no lint (discard)
3. Test file with mock variables → ... still lint (tests should be clean too)
4. `var _x = 0;` (underscore prefix) → no lint (discard convention)

## Quick Fix

Offer "Remove unused variable":
```dart
// Before:
final sorted = items.sorted();
for (final item in items) { ... }

// After:
for (final item in items) { ... }
```

Or "Use the variable":
```dart
// Change items → sorted in the loop
```

## Notes & Issues

1. **CRITICAL: Check if built-in `unused_local_variable` can be elevated to WARNING** — if `analysis_options.yaml` can configure the severity of built-in hints, this custom rule is unnecessary overhead.
2. **Scope analysis complexity**: Detecting unused variables requires traversing all references in the variable's scope. This is significantly harder than most other rules. Consider using `element.references` if the Dart analysis API provides it.
3. **`count++` but never read** — this is a particularly subtle case where a variable is WRITTEN (increment) but never READ. The built-in rule should also catch this.
4. **Test files**: Unlike many other rules, unused variables in test files are ALSO a problem and should be flagged.

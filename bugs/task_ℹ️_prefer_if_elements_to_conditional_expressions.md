# Task: `prefer_if_elements_to_conditional_expressions`

## Summary
- **Rule Name**: `prefer_if_elements_to_conditional_expressions`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Flutter Widgets / Code Quality

## Problem Statement
Using ternary (conditional) expressions inside list, map, or set literals when one branch evaluates to `null` is a common but problematic pattern in Flutter widget trees. The expression `condition ? someWidget : null` does two things wrong:

1. **Injects `null` into the collection**: If the collection is `List<Widget>`, Dart allows `null` via `List<Widget?>`, which then requires null-aware handling downstream. The `Column` and `Row` widgets do not accept nullable children, so developers often use `.whereType<Widget>()` or `.whereNotNull()` as a downstream workaround, adding more noise.
2. **Obscures intent**: The `if` element syntax (`if (condition) widget`) was introduced precisely to handle this case. It reads as plain English and produces no null entries.

Ternary expressions in collections where both branches are non-null are not targeted — in that case, the ternary is actually preferable to an `if`/`else` element pair.

## Description (from ROADMAP)
Detects ternary expressions inside list, map, or set literals where one branch is `null`, encouraging replacement with Dart's `if` element syntax.

## Trigger Conditions
- A `ConditionalExpression` (ternary `? :`)
- The ternary is a direct element of a `ListLiteral`, `SetOrMapLiteral`, or another collection literal (i.e., its parent is a collection literal element list, not nested inside another expression)
- Either the `thenExpression` or the `elseExpression` is a `NullLiteral`

## Implementation Approach

### AST Visitor
```dart
context.registry.addConditionalExpression((node) {
  // ...
});
```

### Detection Logic
1. Check whether the `node`'s parent is a collection literal element context:
   - `node.parent is ListLiteral` — the ternary is a direct element
   - `node.parent is SetOrMapLiteral` — the ternary is a direct element (key or value)
   - More specifically: the node must be in the `elements` list of the literal, not wrapped in another expression
2. Check whether `node.thenExpression` is a `NullLiteral` OR `node.elseExpression` is a `NullLiteral`.
3. Confirm the collection literal is typed as a non-nullable element type (i.e., `List<Widget>`, not `List<Widget?>`) — a null branch in a nullable-typed collection may be intentional.
4. Report the entire `ConditionalExpression` node.

### Parent Detection Helper
```dart
bool _isDirectCollectionElement(ConditionalExpression node) {
  final parent = node.parent;
  return parent is ListLiteral || parent is SetOrMapLiteral;
}
```

## Code Examples

### Bad (triggers rule)
```dart
// Null in list — use if element instead.
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Title'),
      isLoading ? const CircularProgressIndicator() : null, // LINT
      hasError ? Text(errorMessage) : null, // LINT
      Text('Footer'),
    ].whereType<Widget>().toList(), // downstream workaround noise
  );
}

// Null in map value.
final Map<String, Widget?> slots = {
  'header': showHeader ? const Header() : null, // LINT
  'footer': const Footer(),
};

// Ternary with null in a spread — still a bad pattern.
final items = [
  ...baseItems,
  showExtra ? const ExtraItem() : null, // LINT
];
```

### Good (compliant)
```dart
// If element — clean, no null, self-documenting.
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Title'),
      if (isLoading) const CircularProgressIndicator(),
      if (hasError) Text(errorMessage),
      Text('Footer'),
    ],
  );
}

// Both branches non-null — ternary is fine here.
Widget build(BuildContext context) {
  return Column(
    children: [
      isLoading
          ? const CircularProgressIndicator() // non-null
          : const Icon(Icons.check),           // non-null — no lint
    ],
  );
}

// Explicitly nullable collection — may be intentional.
final List<Widget?> nullableWidgets = [
  condition ? Text('x') : null, // OK if List<Widget?> is intentional
];
```

## Edge Cases & False Positives
- **Both branches non-null**: `condition ? widgetA : widgetB` — do not flag. Both branches have values and `if`/`else` element would be more verbose.
- **Null in a `List<Widget?>`**: If the collection is explicitly typed as nullable elements, injecting null may be intentional. Check the inferred type before reporting.
- **Ternary not a direct element**: `[foo(condition ? x : null)]` — the ternary is inside a function call inside the list. Do not flag — only flag direct list elements.
- **Nested spread with ternary**: `[...?(condition ? list : null)]` — the null-aware spread `...?` is a legitimate pattern. Do not flag null in the context of null-aware spread.
- **Map key vs value**: A null map key is almost always a bug and is covered by other rules. For map values, apply the same logic as lists.
- **`SliverList`, `CustomScrollView`**: These use `slivers` lists — same pattern applies.
- **Generated code**: Skip `*.g.dart` and similar.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: null else branch in list
final w1 = <Widget>[
  condition ? Text('x') : null, // LINT
];

// Test 2: null then branch in list
final w2 = <Widget>[
  condition ? null : Text('x'), // LINT
];

// Test 3: null in map value
final m1 = <String, Widget?>{
  'key': condition ? Text('x') : null, // LINT
};
```

### Should NOT Trigger (compliant)
```dart
// Test 4: both branches non-null
final w3 = <Widget>[
  condition ? Text('a') : Text('b'), // No lint
];

// Test 5: ternary not a direct element
final w4 = <Widget>[
  Padding(padding: EdgeInsets.zero, child: condition ? Text('x') : Text('y')),
];

// Test 6: null-aware spread — different pattern
final w5 = [
  ...?(condition ? [Text('x')] : null), // Different pattern — no lint here
];
```

## Quick Fix
**Message**: "Replace conditional expression with an if element"

The fix should handle two cases:

**Case 1**: `condition ? expr : null`
```dart
// Before:
[condition ? expr : null]
// After:
[if (condition) expr]
```

**Case 2**: `condition ? null : expr`
```dart
// Before:
[condition ? null : expr]
// After:
[if (!condition) expr]
```

The fix:
1. Replaces the `ConditionalExpression` node text with `if (<condition>) <non-null-expr>`.
2. Negates the condition appropriately for Case 2.
3. Removes any `.whereType<Widget>().toList()` chain that becomes unnecessary — but this secondary cleanup is optional and should be a separate suggestion.

## Notes & Issues
- This pattern is extremely common in Flutter codebases — expect a high trigger rate. Tier as Recommended to ensure visibility.
- Dart's official linter includes `prefer_if_elements_to_conditional_expressions` — check that implementation for prior art before writing from scratch.
- The rule must not flag ternaries that are not inside a collection literal — that would be an overreach into general expression style.
- Consider a companion rule or lint note that flags `.whereType<Widget>().toList()` chains, suggesting the use of `if` elements instead.

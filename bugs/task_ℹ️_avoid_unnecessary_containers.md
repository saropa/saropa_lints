# Task: `avoid_unnecessary_containers`

## Summary
- **Rule Name**: `avoid_unnecessary_containers`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Flutter Widgets

## Problem Statement
A `Container` widget with only a `child` property (no decoration, constraints, color, margin, padding, alignment, etc.) adds an extra layer to the widget tree with no benefit. Every unnecessary widget in the tree increases the cost of layout, painting, and hit-testing. Dart's widget composition model makes it trivially easy to reach for `Container` as a default wrapper, but when no container-specific properties are used the child should simply be used directly.

This pattern frequently appears when developers refactor code — they remove the decorating properties but leave the `Container` shell — or when copy-pasting widget patterns.

## Description (from ROADMAP)
Detects `Container` widgets that provide no value because they set no properties beyond `child`, making them pure widget-tree noise.

## Trigger Conditions
- An `InstanceCreationExpression` targeting the `Container` constructor
- The constructor's argument list contains only a `child` named argument (optionally also a `key` named argument)
- No other named arguments are present: no `color`, `decoration`, `constraints`, `margin`, `padding`, `alignment`, `width`, `height`, `transform`, `transformAlignment`, `clipBehavior`, or `foregroundDecoration`

## Implementation Approach

### AST Visitor
```dart
context.registry.addInstanceCreationExpression((node) {
  // ...
});
```

### Detection Logic
1. Resolve the static type of the created instance.
2. Check whether the type is `Container` from `package:flutter/widgets.dart`.
3. Collect all named arguments in the argument list.
4. Filter out `key` (which is inherited from `Widget` and does not contribute to layout or painting behaviour).
5. If the remaining named arguments are exactly `{child}` — or empty (no child at all, but that is covered by a different rule) — report the node.
6. Do **not** report if any of the following arguments are present: `color`, `decoration`, `foregroundDecoration`, `width`, `height`, `constraints`, `margin`, `padding`, `alignment`, `transform`, `transformAlignment`, `clipBehavior`.

## Code Examples

### Bad (triggers rule)
```dart
// Wraps child with no additional container properties.
Widget build(BuildContext context) {
  return Container(
    child: Text('Hello'),
  );
}

// Key-only is also redundant — the Container still provides nothing.
Widget build(BuildContext context) {
  return Container(
    key: const ValueKey('greeting'),
    child: Text('Hello'),
  );
}

// No child at all — Container() adds nothing.
Widget build(BuildContext context) {
  return Container();
}
```

### Good (compliant)
```dart
// Use the child directly.
Widget build(BuildContext context) {
  return Text('Hello');
}

// Container with padding — justified use.
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(8),
    child: Text('Hello'),
  );
}

// Container with color — justified use.
Widget build(BuildContext context) {
  return Container(
    color: Colors.blue,
    child: Text('Hello'),
  );
}

// Container with width/height constraints — justified use.
Widget build(BuildContext context) {
  return Container(
    width: 200,
    height: 100,
    child: Text('Hello'),
  );
}

// Container with decoration — justified use.
Widget build(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey),
    ),
    child: Text('Hello'),
  );
}
```

## Edge Cases & False Positives
- **`key` parameter only**: A `Container(key: k, child: w)` is still redundant — the `key` can be placed on the child widget directly. Report this case.
- **`AnimatedContainer`**: A different class; should not be flagged by this rule. Only target `Container` exactly.
- **`DecoratedBox`, `Padding`, `Align`, etc.**: These are the correct replacements when specific properties are needed — the rule should suggest removing the Container, not replacing it with another widget (the fix can note appropriate replacements in the correction message).
- **Container with `clipBehavior`**: `clipBehavior` is a valid Container-specific property; do not flag.
- **Container as a type annotation or cast**: Only flag `InstanceCreationExpression`, not type references.
- **Containers inside generated code**: If the code is in a generated file (`.g.dart`, `.freezed.dart`), skip — generated code may have structural reasons for the extra layer.
- **Subclasses of Container**: If a developer has subclassed `Container`, the rule should not flag instances of the subclass.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: bare Container with only child
Widget test1() => Container(child: Text('x')); // LINT

// Test 2: Container with key and child only
Widget test2() => Container(key: Key('k'), child: Text('x')); // LINT

// Test 3: Container with no arguments
Widget test3() => Container(); // LINT
```

### Should NOT Trigger (compliant)
```dart
// Test 4: Container with padding
Widget test4() => Container(padding: EdgeInsets.zero, child: Text('x'));

// Test 5: Container with color
Widget test5() => Container(color: Colors.red, child: Text('x'));

// Test 6: Container with width
Widget test6() => Container(width: 100, child: Text('x'));

// Test 7: Container with decoration
Widget test7() => Container(
  decoration: BoxDecoration(color: Colors.red),
  child: Text('x'),
);

// Test 8: AnimatedContainer — not targeted
Widget test8() => AnimatedContainer(
  duration: Duration(milliseconds: 300),
  child: Text('x'),
);
```

## Quick Fix
**Message**: "Remove unnecessary Container and use the child directly"

The fix should:
1. Replace the entire `Container(child: expr)` expression with just `expr`.
2. If there is no child, replace with `const SizedBox.shrink()` (a common Flutter idiom for an empty, zero-size widget) and note this in the correction message.
3. If a `key` was present, migrate the key to the child expression: `child.withKey(key)` — but since Dart has no such method, the fix should add `Key` to the child widget's constructor if it accepts one, or wrap in a `KeyedSubtree` widget.

## Notes & Issues
- The rule targets Flutter code only — it should short-circuit if the project does not use Flutter (`ProjectContext.isFlutterProject`).
- The `Container` class is from `package:flutter/widgets.dart`. Use type-based detection (`node.staticType`) rather than string matching on the identifier name to avoid false positives with any user-defined `Container` class.
- Consider a companion rule or correction message that guides developers toward the right replacement widget (`Padding`, `ColoredBox`, `SizedBox`, `Align`) rather than just saying "remove it".
- Flutter's own linter has a similar lint (`avoid_unnecessary_containers`) in `flutter_lints` — check its implementation for reference, and consider whether saropa_lints should defer to it or provide a stricter/different version.

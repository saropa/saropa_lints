# Task: `avoid_deep_nesting`

## Summary
- **Rule Name**: `avoid_deep_nesting`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.47 Widget Composition Rules

## Problem Statement

Deeply nested widget trees in Flutter cause multiple problems:

1. **Performance**: Deep widget trees take longer to traverse during build, layout, and paint phases
2. **Readability**: Deeply nested code ("pyramid of doom") is hard to understand and maintain
3. **Refactoring difficulty**: Extracting widgets from deeply nested trees is error-prone
4. **Debugger difficulty**: Flutter DevTools shows deep trees as long stacks of widget types
5. **Stack overflow risk**: Extremely deep trees (100+) can cause stack overflows during recursive traversal

```dart
// Pyramid of doom — 10+ nesting levels
return Scaffold(
  body: SafeArea(
    child: Center(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(...),
                child: ClipRRect(
                  child: Stack(
                    children: [  // ← already 10 levels deep
```

## Description (from ROADMAP)

> Widgets shouldn't nest too deeply. Detect nesting >10 levels.

## Trigger Conditions

1. Widget constructor nesting depth > 10 levels within a single `build()` method
2. Depth measured as consecutive `InstanceCreationExpression` nodes (widget constructors) in the AST

**Threshold**: 10 levels is the stated limit in the ROADMAP. This is a reasonable threshold — legitimate Flutter UIs often nest 5-8 levels.

## Implementation Approach

```dart
context.registry.addMethodDeclaration((node) {
  if (node.name.lexeme != 'build') return;
  if (!_isWidgetBuildMethod(node)) return;

  _checkNestingDepth(node.body, 0, reporter);
});

void _checkNestingDepth(AstNode node, int depth, reporter) {
  if (node is InstanceCreationExpression && _isWidgetConstructor(node)) {
    if (depth > 10) {
      reporter.atNode(node, code);
      return; // Don't recurse further — already flagged
    }
    // Recurse into children/child arguments
    for (final child in _getChildNodes(node)) {
      _checkNestingDepth(child, depth + 1, reporter);
    }
  }
}
```

## Code Examples

### Bad (Should trigger — >10 widget levels)
```dart
Widget build(BuildContext context) {
  return Scaffold(           // level 1
    body: SafeArea(          // level 2
      child: Center(         // level 3
        child: Column(       // level 4
          children: [
            Expanded(        // level 5
              child: Padding(// level 6
                child: Card( // level 7
                  child: Column( // level 8
                    children: [
                      Padding(   // level 9
                        child: Row( // level 10
                          children: [
                            Icon(...), // level 11 ← trigger
```

### Good (Should NOT trigger)
```dart
// Extract widgets into methods or classes
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: Center(
        child: _buildContent(), // ← extracted, reduces nesting
      ),
    ),
  );
}

Widget _buildContent() {
  return Column(
    children: [
      _buildCard(),
    ],
  );
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Builders (LayoutBuilder, Builder, etc.) that count as nesting | **Count** — builders add nesting | |
| Sliver widgets in CustomScrollView | **Count** — each sliver is a level | |
| Generated code | **Suppress** | |
| Test widgets | **Suppress** | |
| Depth exactly at 10 | **Suppress** | Flag > 10 |

## Unit Tests

### Violations
1. `build()` method with 11+ nested widget constructors → 1 lint
2. Deep nesting in only one branch of a Column → 1 lint

### Non-Violations
1. 10-level nesting → no lint
2. 8-level nesting → no lint
3. Deeply nested code that's not in a `build()` method → no lint

## Quick Fix

No automated fix — reducing nesting requires extracting subtrees into separate widget classes or builder methods. Suggest "Extract to a separate widget or method".

## Notes & Issues

1. **Flutter-only**: Only fire if `ProjectContext.isFlutterProject`.
2. **Nesting counting**: The tricky part is counting "widget nesting" correctly. `children: [...]` flattens nesting (siblings don't count as nesting), but each `child:` counts. The implementation must count along the `child` path, not all descendants.
3. **`LayoutBuilder`, `Builder`, `MediaQueryScope`**: These are not visual widgets but create nesting in the AST. Include them in the count.
4. **Performance cost of the lint**: Walking the entire widget tree for every `build()` method may be slow. Limit depth tracking to `build()` methods and use early return when threshold is exceeded.
5. **Threshold configurability**: Consider making the threshold configurable via `analysis_options.yaml`. Some legacy codebases may need a higher threshold (15+) as an intermediate goal before refactoring.
6. **The correct fix**: Extract widgets into named widget classes (not just private methods) for maximum performance benefit — methods are still inlined by Flutter's build system, but separate widget classes get their own `canUpdate` and rebuild isolation.

# Task: `avoid_repeated_widget_creation`

## Summary
- **Rule Name**: `avoid_repeated_widget_creation`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.47 Widget Composition Rules

## Problem Statement

Creating identical widget instances multiple times in a `build()` method or in a list comprehension wastes CPU and memory:

1. Each `new` widget instance costs allocation time
2. Identical widgets with no changing state should be shared/cached
3. When the same widget appears multiple times (e.g., in a list), Flutter creates N separate widget instances even if they are identical

```dart
// BAD: Same widget created N times with identical parameters
Widget build(BuildContext context) {
  return Column(
    children: List.generate(100, (i) => Container(
      color: Colors.blue,  // ← same color
      width: 50,           // ← same size
      height: 50,          // ← same size
      // ← creates 100 separate Container instances
    )),
  );
}
```

For truly static widgets with no changing parameters, using `const` solves this — the `const` constructor creates a single shared instance.

## Description (from ROADMAP)

> Cache widget references when possible. Detect identical widgets created in loop.

## Trigger Conditions

1. A widget constructor created inside a `List.generate`, `map`, `for` loop where all arguments are **constants** (no `index`-dependent values)
2. The same widget constructed multiple times in a `children:` list with identical constant arguments

**Phase 1 (Conservative)**: Only flag when ALL arguments to the widget constructor are `const` values (literals, constant references) AND the constructor call is inside a loop/map.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  // Look for List.generate, .map, etc.
  if (!_isCollectionGenerator(node)) return;

  // Check if the builder function creates a widget with all-const args
  final builder = _getBuilderArg(node);
  if (!_isIndexIndependent(builder)) return; // builder doesn't use the index
  // If all args are const, the widget could be cached
  if (_allArgsAreConst(builder)) {
    reporter.atNode(builder, code);
  }
});
```

`_isIndexIndependent`: check if the builder closure/function doesn't reference the index parameter.

## Code Examples

### Bad (Should trigger)
```dart
// Same widget created 100 times — could be const
Column(
  children: List.generate(100, (_) => Container( // ← trigger: index unused
    color: Colors.blue,
    width: 50,
    height: 50,
  )),
)

// Multiple identical entries in children list
Column(
  children: [
    const Divider(),
    SomeWidget(),  // ← might be const
    const Divider(), // ← same as above, could be one const
    SomeWidget(),
  ],
)
```

### Good (Should NOT trigger)
```dart
// Index-dependent — different widgets each time
Column(
  children: List.generate(100, (i) => ListTile(
    title: Text('Item $i'), // ← uses index
  )),
)

// Const widget in loop (already optimized)
Column(
  children: List.generate(5, (_) => const Divider()), // ← const is already shared
)

// Cached reference
static const _divider = Divider(height: 1);

Column(
  children: [
    _divider, // ← reuses same instance
    SomeWidget(),
    _divider,
  ],
)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `const` constructor call in loop | **Suppress** — already a const (shared instance) | |
| Loop with index as item count (not widget parameter) | **Suppress** — loop structure, not arg | |
| `List.filled(n, widget)` with same widget | **Flag** — repeated creation | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `List.generate(100, (_) => Container(color: Colors.blue))` (non-const, index unused) → 1 lint

### Non-Violations
1. `List.generate(100, (_) => const Divider())` → no lint (already const)
2. `List.generate(100, (i) => Text('$i'))` → no lint (index-dependent)
3. Static `Column` without loop → no lint

## Quick Fix

Offer "Make `const`" or "Cache as a static field":
```dart
// Before
List.generate(100, (_) => Container(color: Colors.blue, width: 50, height: 50))

// After: const (if widget supports it)
List.generate(100, (_) => const ColoredBox(color: Colors.blue))

// After: cached static
static const _item = Container(color: Colors.blue, width: 50, height: 50);
List.generate(100, (_) => _item)
```

## Notes & Issues

1. **Flutter-only**: Only fire if `ProjectContext.isFlutterProject`.
2. **`const` is the real fix**: In Dart, `const` constructors create canonicalized instances — the same `const Widget()` call always returns the same instance. If the widget supports `const`, making it `const` is the correct fix.
3. **Not all identical widgets should be cached**: Widgets that hold state (even if their parameters are identical) should each have their own instance. Detect only stateless, `const`-compatible widgets.
4. **Performance impact**: For 5-10 identical widgets in a list, the performance difference is negligible. This rule matters for lists of 50+ items with heavy widget trees.
5. **Flutter's diff algorithm**: Flutter's widget reconciliation (element tree diffing) can reuse elements, but only if the widget type and key match. Creating new instances doesn't prevent reuse — Flutter is smart enough. The real cost is object allocation and GC pressure.
6. **HIGH FALSE POSITIVE RISK**: The detection of "all arguments are const" is complex. Phase 1 should be very conservative — only flag when the builder is `(_) => SomeWidget()` with no arguments at all, or trivially constant arguments (literals).

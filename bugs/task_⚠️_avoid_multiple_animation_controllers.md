# Task: `avoid_multiple_animation_controllers`

## Summary
- **Rule Name**: `avoid_multiple_animation_controllers`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.20 Animation Performance Rules

## Problem Statement

Multiple `AnimationController` instances in a single `State` class cause coordination problems and resource waste:

1. **Lifecycle complexity**: Each controller requires `dispose()` — easy to forget one
2. **Synchronization bugs**: If controllers need to run together, timing drift can cause visual glitches
3. **Resource overhead**: Each controller creates a `Ticker` that fires on every vsync
4. **Complexity**: Multiple controllers competing for widget rebuilds can cause jank

Common symptoms:
```dart
class _MyWidgetState extends State<MyWidget> with TickerProviderStateMixin {
  late AnimationController _fadeController;     // controller 1
  late AnimationController _slideController;    // controller 2
  late AnimationController _scaleController;    // controller 3 ← three controllers!

  // Complex synchronization logic needed...
  // And three separate dispose() calls
}
```

The alternatives:
1. **`AnimationController` with `TweenSequence`** — single controller, multiple values
2. **`staggered_animations` package** — declarative staggered animations
3. **Rive / Lottie** — complex animations handled externally

## Description (from ROADMAP)

> Multiple controllers on same widget conflict. Detect multiple controllers without coordination.

## Trigger Conditions

1. A `State` class (extending `State<T>`) with more than **2** `AnimationController` field declarations
2. The controllers lack an `_coordinateAnimations()` method or other coordination mechanism

**Threshold: 2 controllers** — having 2 is a common legitimate pattern (e.g., enter animation + exit animation). Flag at 3+.

## Implementation Approach

```dart
context.registry.addClassDeclaration((node) {
  if (!_isStateClass(node)) return;

  final controllers = node.members
      .whereType<FieldDeclaration>()
      .where(_isAnimationController)
      .toList();

  if (controllers.length >= 3) {
    reporter.atNode(node.name, code);
  }
});
```

`_isStateClass`: check if class extends `State<T>`.
`_isAnimationController`: check if field type is `AnimationController` or `late AnimationController`.

## Code Examples

### Bad (Should trigger)
```dart
class _ProductCardState extends State<ProductCard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;    // ← count: 1
  late AnimationController _slideController;   // ← count: 2
  late AnimationController _bounceController;  // ← count: 3 → trigger

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: ...);
    _slideController = AnimationController(vsync: this, duration: ...);
    _bounceController = AnimationController(vsync: this, duration: ...);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bounceController.dispose(); // ← easy to forget
    super.dispose();
  }
}
```

### Good (Should NOT trigger)
```dart
// Single controller with TweenSequence
class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;  // only 1 controller

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ...);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| 2 controllers | **Suppress** — threshold is 3 | |
| 3 controllers with explicit coordination comments | **Trigger** — still a code smell | |
| Mixin adding controllers | **Complex** — mixin controllers not visible in class body | |
| Static controller shared across instances | **Suppress** — different concern | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. State class with 3+ `AnimationController` fields → 1 lint

### Non-Violations
1. State class with 1 `AnimationController` → no lint
2. State class with 2 `AnimationController` fields → no lint
3. Non-State class with multiple controllers → no lint

## Quick Fix

No automated fix — consolidating controllers requires architectural changes. Suggest "Consider using a single controller with `TweenSequence` or `Interval`".

## Notes & Issues

1. **Threshold**: 2 is common (forward/reverse, or two independent animations). Flag at 3+. Consider making the threshold configurable.
2. **`TickerProviderStateMixin` vs `SingleTickerProviderStateMixin`**: Using `SingleTickerProviderStateMixin` with multiple controllers causes a runtime error. Conversely, using `TickerProviderStateMixin` with only 1 controller is a minor waste. A separate rule could enforce the correct mixin.
3. **Animation packages**: `staggered_animations`, `flutter_animate`, and `rive` all help avoid multiple manual controllers. If these packages are detected, suppress the warning.
4. **Missing dispose check**: A companion rule `require_animation_controller_dispose` would check that every `AnimationController` field has a corresponding `dispose()` call in the `dispose()` method.
5. **Async animations**: Sometimes controllers are needed for independent, non-synchronized animations (e.g., a background pulse and a foreground shimmer). This is a legitimate use case that may cause false positives.

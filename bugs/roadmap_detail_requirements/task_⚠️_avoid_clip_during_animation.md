# Task: `avoid_clip_during_animation`

## Summary
- **Rule Name**: `avoid_clip_during_animation`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.20 Animation Performance Rules

## Problem Statement

`ClipRect`, `ClipRRect`, `ClipOval`, and `ClipPath` trigger **expensive rasterization operations** on every animation frame. When a clip is applied to an animated widget, the GPU must re-clip the content 60+ times per second:

1. **Layer promotion**: Flutter may promote the clipped layer to a new compositing layer, but the clipping operation itself is expensive
2. **Rasterization cost**: `ClipPath` especially causes software rasterization (not GPU-accelerated) which is extremely expensive
3. **Janky animations**: Clipping during animations causes frame time to exceed 16ms, causing dropped frames

The correct approach: **pre-clip before the animation starts**, or structure the widget tree so the clip is outside the animated scope:

```dart
// BAD: Clip inside animation — re-clips every frame
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  child: ClipRRect(  // ← re-clips on every animation frame
    borderRadius: BorderRadius.circular(16),
    child: Image.network(imageUrl),
  ),
)
```

## Description (from ROADMAP)

> Pre-clip content before animating. Detect ClipRect in animated widget.

## Trigger Conditions

1. Any `ClipX` widget (ClipRect, ClipRRect, ClipOval, ClipPath) as a **descendant** of an animated widget:
   - `AnimatedContainer`
   - `AnimatedOpacity`
   - `AnimatedPositioned`
   - `AnimatedWidget` subclasses
   - `AnimatedBuilder` with a builder
   - `Transition` widgets (`FadeTransition`, `SlideTransition`, `ScaleTransition`, etc.)

## Implementation Approach

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isClipWidget(node)) return;
  if (!_isInsideAnimatedWidget(node)) return;
  reporter.atNode(node, code);
});
```

`_isClipWidget`: check constructor name is `ClipRect`, `ClipRRect`, `ClipOval`, `ClipPath`.
`_isInsideAnimatedWidget`: walk the parent InstanceCreationExpression chain looking for animated widget constructors.

**Important**: "descendant" means at any depth in the widget tree (in the arguments, not just direct parent). This requires walking up the AST node's argument-lists.

## Code Examples

### Bad (Should trigger)
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  height: _isExpanded ? 200 : 0,
  child: ClipRect(  // ← trigger: ClipRect inside animated widget
    child: ListView(...),
  ),
)

FadeTransition(
  opacity: _animation,
  child: ClipRRect(  // ← trigger
    borderRadius: BorderRadius.circular(12),
    child: Image.asset('assets/hero.jpg'),
  ),
)
```

### Good (Should NOT trigger)
```dart
// Clip OUTSIDE the animation
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: AnimatedContainer(  // ← animation is inside the clip
    duration: const Duration(milliseconds: 300),
    child: Image.asset('assets/hero.jpg'),
  ),
)

// Use decoration instead of ClipRRect for round corners with animation
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),  // ← no clip needed
    image: DecorationImage(image: AssetImage('assets/hero.jpg')),
  ),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `ClipRect(clipBehavior: Clip.none)` | **Suppress** — effectively a no-op | |
| Clip in a list that contains an animated widget | **Trigger** only if clip is direct child | |
| Custom AnimatedWidget subclass | **Trigger** if class name ends with `Animated` or `Transition` | |
| `RepaintBoundary` wrapping the animated widget | **Suppress** — effectively isolates the paint | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `AnimatedContainer` with `ClipRect` child → 1 lint
2. `FadeTransition` with `ClipRRect` as descendant → 1 lint
3. `AnimatedOpacity` with `ClipOval` → 1 lint

### Non-Violations
1. `ClipRRect` with `AnimatedContainer` as child (clip wraps animation) → no lint
2. Static `ClipRect` not inside any animation → no lint

## Quick Fix

Offer "Move `ClipRRect` outside the animation":
```dart
// Before
AnimatedContainer(
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: content,
  ),
)

// After
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: AnimatedContainer(
    child: content,
  ),
)
```

## Notes & Issues

1. **AST parent walking**: Walking parent nodes in an AST visitor context is available via `node.parent`. Walking up to find animated ancestor requires iterating through parents checking each one.
2. **Depth limit**: Limit the ancestor search to a reasonable depth (5-7 levels) to avoid performance issues in the lint runner.
3. **`RepaintBoundary`**: Adding `RepaintBoundary` between the animated widget and the clip can also solve this — the clip's layer would be isolated. Consider allowing this as a suppression.
4. **`SliverAnimatedList`**: Sliver variants should also be detected.
5. **Performance impact varies by clip type**:
   - `ClipRect` — relatively cheap
   - `ClipRRect` — moderate
   - `ClipOval` — moderate
   - `ClipPath` — most expensive (software rendering path)
   Consider adjusting severity by clip type (only flag `ClipPath` and `ClipRRect`).

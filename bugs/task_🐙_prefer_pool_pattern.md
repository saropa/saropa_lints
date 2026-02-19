# Task: `prefer_pool_pattern`

## Summary
- **Rule Name**: `prefer_pool_pattern`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.3 Performance Rules — Memory Optimization
- **GitHub Issue**: [#13](https://github.com/saropa/saropa_lints/issues/13)
- **Priority**: 🐙 Has active GitHub issue

## Problem Statement

Dart's garbage collector is a generational GC — it is efficient for long-lived objects but incurs cost when short-lived objects are rapidly created and destroyed. In games, particle systems, or UI layers with high-frequency item creation (e.g., chat bubbles, bullet hell), thousands of object allocations per second can cause GC pauses that drop frames below 60fps.

The object pool pattern avoids this: pre-allocate a pool of reusable objects, check one out when needed, and return it when done. Flutter's `RecyclerPool` (used internally in the rendering engine) and packages like `object_pool` implement this.

## Description (from ROADMAP)

> Frequently created/destroyed objects cause GC churn. Object pools reuse instances (e.g., for particles, bullet hell games, or recyclable list items).

## Trigger Conditions

This rule fires when it detects:
1. `InstanceCreationExpression` inside a hot loop (tight animation loop, `for` with many iterations, `Timer.periodic` callback) for a class that:
   - Is non-trivial (has multiple fields, not just a data class)
   - Is short-lived (created and immediately used, with no long-lived reference)
2. A pattern like `List<T>` used as a "manual pool" without proper acquire/release semantics

**Note**: This is inherently a heuristic rule with high false positive potential. Phase 1 should be very conservative.

### Phase 1 Heuristic
Detect `InstanceCreationExpression` inside:
- `AnimationController.addListener(...)` callbacks
- `Ticker.tick` callbacks
- `Timer.periodic(...)` callbacks
- `SchedulerBinding.addPersistentFrameCallback(...)`

where the type being constructed has:
- More than 3 fields (suggesting non-trivial allocation)
- No `const` constructor

## Implementation Approach

### Package Detection
Check if project uses `object_pool` or similar — if so, they may already be using pools. Note in message but don't suppress.

### AST Visitor Pattern

```dart
context.registry.addInstanceCreationExpression((node) {
  if (node.isConst) return;  // const allocations are free (deduped)
  if (!_isInsideHotLoop(node)) return;
  if (!_isNonTrivialType(node)) return;
  reporter.atNode(node, code);
});
```

`_isInsideHotLoop`: walk parents for `FunctionExpression` that is passed to:
- `Timer.periodic` second argument
- `AnimationController.addListener`
- `addPersistentFrameCallback`
- `addPostFrameCallback` (if called very frequently)

`_isNonTrivialType`: check constructor's class for field count > 3, or look up class declaration.

## Code Examples

### Bad (Should trigger)
```dart
// Creating new Particle on every frame (60 fps = 60 allocations/sec per particle)
void _onTick(Duration elapsed) {
  final particle = Particle(  // ← trigger
    position: Offset.zero,
    velocity: Offset(random.nextDouble(), random.nextDouble()),
    color: Colors.red,
    size: 5.0,
  );
  _particles.add(particle);
}

// In Timer.periodic callback
Timer.periodic(Duration(milliseconds: 16), (timer) {
  final update = PositionUpdate(x: _x, y: _y, z: _z);  // ← trigger
  _sendUpdate(update);
});
```

### Good (Should NOT trigger)
```dart
// Using object pool ✓
final _pool = ObjectPool<Particle>(factory: Particle.new, maxSize: 100);

void _onTick(Duration elapsed) {
  final particle = _pool.acquire();  // reused from pool
  particle.reset(position: Offset.zero, ...);
  _particles.add(particle);
}

// Const construction — free ✓
void _onTick(Duration elapsed) {
  const particle = Particle.empty;  // const, no allocation
}

// Simple data class with 1-2 fields — cheap ✓
void _onTick(Duration elapsed) {
  final point = Point(x, y);  // small, quickly GC'd
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `Offset(x, y)` created in animation frame | **Suppress** — built-in value types are stack-allocated or very cheap | Whitelist known cheap types: `Offset`, `Size`, `Rect`, `Color` |
| `Future` / `Stream` creation in timer | **Suppress** — async machinery, not domain objects | Complex to detect |
| Very fast timer (16ms) but creates 1 small object | **Suppress if type is simple** — GC handles this | Field count threshold |
| `const` constructor called | **Always suppress** — const objects are singletons | |
| Object created in `addPostFrameCallback` called once | **Suppress** — single-shot callbacks are not hot loops | Check callback registration context |
| Test file | **Suppress** | `ProjectContext.isTestFile` |
| `ListView.builder` calling constructor for each item | **Phase 2** — ListView items aren't created 60x/sec but can be thousands | Different pattern; note for future |
| GPU/Isolate boundary — objects that can't be shared | **Note in message** — pools across isolates are not straightforward | |

## Unit Tests

### Violations
1. `InstanceCreationExpression` inside `AnimationController.addListener` for a 5-field class → 1 lint
2. Same inside `Timer.periodic` callback → 1 lint
3. Object creation inside `addPersistentFrameCallback` → 1 lint

### Non-Violations
1. `const` constructor call in hot loop → no lint
2. `Offset(x, y)` in animation frame → no lint (whitelisted)
3. 2-field data class in timer → no lint (below threshold)
4. Object creation in one-shot `addPostFrameCallback` → no lint
5. Test file → no lint

## Quick Fix

No automated quick fix — pool implementation is architecture-level.

```
correctionMessage: 'Consider an object pool to reuse instances instead of allocating on every frame. See package:object_pool or implement a custom pool.'
```

## Notes & Issues

1. **HIGH false positive risk** — this is one of the hardest rules to get right. The heuristic of "non-trivial object in hot loop" will flag many legitimate patterns. Consider requiring explicit opt-in or keeping the INFO severity low-friction.
2. **Whitelisting built-in types** (`Offset`, `Size`, `Rect`, `Color`, `BorderRadius`) is essential to avoid overwhelming false positives.
3. **GitHub Issue #13** — check the issue for additional context, user scenarios, and any discussion of the detection approach.
4. **Consider ROADMAP_DEFERRED** — this rule may belong in the deferred list due to `[TOO-COMPLEX]` detection requirements. The heuristic approach has so many edge cases that implementation quality is uncertain.
5. **ROADMAP duplicate**: This rule appears TWICE in the table (once without 🐙, once with). Both rows should be deleted when resolving this issue.

# PROPOSAL: Flag Heavy Initialization Logic Inside Flame's `onMount()`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

**Package dependency:** `flame`. This rule only applies to projects using the Flame game engine and should only run when `flame` is a declared dependency, targeting classes that extend/mix in Flame's `Component`.

---

## Summary

Add `avoid_initializing_in_on_mount` to flag Flame `Component` subclasses that perform field initialization, resource loading, or state setup inside `onMount()` when that setup does not depend on the component's parent/game tree being attached — such initialization belongs in the constructor or `onLoad()`, both of which run earlier and more predictably, while `onMount()` is meant for logic that specifically requires the component to already be attached to its parent (e.g. reading a parent's size).

**Closes gap:** dart_code_linter `avoid_initializing_in_on_mount` (Flame-specific). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Flame components have a well-defined lifecycle (constructor → `onLoad()` → `onMount()` → `onGameResize()`/`update()`), and `onMount()` re-runs every time a component is re-attached to a different parent (e.g. when reparented), not just once. Initialization that belongs in the constructor or `onLoad()` but is placed in `onMount()` either runs redundantly on every reparent or silently assumes reparenting never happens, both of which are footguns unique to Flame's tree structure.

---

## Detection / Behavior

Flag assignments to instance fields inside an `onMount()` override where the assigned value does not reference `parent` (i.e. does not depend on the parent component being attached).

### Should flag (bad code)

```dart
class Player extends PositionComponent {
  late Sprite sprite;

  @override
  void onMount() {
    super.onMount();
    sprite = Sprite(_spriteImage); // LINT — no parent dependency; belongs in onLoad()
  }
}
```

### Should pass (good code)

```dart
class HealthBar extends PositionComponent {
  late double maxWidth;

  @override
  void onMount() {
    super.onMount();
    maxWidth = parent!.size.x; // OK — genuinely depends on the attached parent
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (Flame) lifecycle rule; only relevant to game-engine projects, appropriate for a deep-review tier.

---

## Edge Cases

1. **`onMount()` that calls `super.onMount()` and nothing else** — should pass; no flagged assignments present.
2. **Assignment inside a conditional that also checks `parent` state (`if (parent is GameWorld) sprite = ...`)** — should pass; the branch itself depends on `parent`, satisfying the intent even if the assigned value doesn't literally reference `parent`.
3. **Assignment to a field already fully initialized in the constructor, reassigned unconditionally in `onMount()`** — should flag; this is the exact redundant-reinitialization-on-every-reparent case the rule targets.
4. **Async work started (not just field assignment) in `onMount()`, e.g. `unawaited(_loadAssets())`** — needs discussion; consider extending detection to flag async work with no `parent` dependency in a follow-up, since it carries the same reparent-repetition risk.

---

## Alternatives Considered

- **Flag any statement at all in `onMount()`, not just field assignment** — rejected as too broad; `onMount()` legitimately contains non-assignment setup (registering listeners, adding children) that isn't the redundant-reinitialization problem this rule targets.

---

## Decision

---

## Implementation Notes

---

## Commits

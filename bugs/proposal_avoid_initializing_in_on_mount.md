# PROPOSAL: Flag Component Initialization Inside Flame's `onMount()`

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `flame` game-engine package)
Related rules: none

---

## Summary

Add `avoid-initializing-in-on-mount` (saropa id: `avoid_initializing_in_on_mount`) to flag component field
initialization — assigning final/required state, allocating resources, constructing child components — done
inside a Flame `Component`'s `onMount()` override instead of its constructor or `onLoad()`. `onMount()` runs
every time a component is (re)attached to a parent (including after being removed and re-added), so
initialization placed there re-runs on every remount instead of once per component lifetime.

**Closes gap:** `dart_code_metrics_presets` / `dart_code_linter` `avoid-initializing-in-on-mount` (Flame
preset). Confirmed zero Flame-specific rules exist on either saropa or the official Flame-org preset side.
Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`
"Uncovered ecosystem packages" section.

---

## Motivation

Flame's component lifecycle has distinct phases: the constructor runs once, `onLoad()` runs once
(async-capable, before first mount), and `onMount()` runs every time the component attaches to a parent —
which can happen more than once if a component is removed and re-added to the tree (a common pattern for
object pooling / reparenting in games). Code that assigns state or builds child objects in `onMount()`
silently re-executes on every reattach, which is rarely the intended behavior and is a well-known Flame
footgun. saropa has no Flame-aware rules at all; this is confirmed to be genuinely unaddressed even by
Flame's own official lint preset.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Player extends PositionComponent {
  late final Sprite sprite;

  @override
  void onMount() {
    super.onMount();
    sprite = Sprite(Images.player); // LINT — avoid_initializing_in_on_mount: re-runs on every remount; belongs in onLoad()
  }
}
```

### Should pass (good code)

```dart
class Player extends PositionComponent {
  late final Sprite sprite;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = Sprite(Images.player); // OK — onLoad() runs once per component lifetime
  }
}
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `flame` dependency note)
Justification: Only fires in projects depending on `flame`; lifecycle-correctness footgun specific to a game
engine, not a universal Dart/Flutter concern.

---

## Edge Cases

1. **`onMount()` that only reads parent/tree state without assigning new fields** (e.g. repositioning
   relative to a newly-attached parent) — should pass; re-deriving position from the current parent on every
   mount is a legitimate, idiomatic use of `onMount()`.
2. **Idempotent re-assignment guarded by a null check** (`sprite ??= Sprite(...)`) — needs discussion; still
   arguably belongs in `onLoad()`, but the guard demonstrates awareness of the re-entry hazard — consider
   whether to exempt guarded assignments or still flag them as misplaced.
3. **`super.onMount()` call itself** — should pass; only user-added initialization statements are in scope,
   not the required super call.
4. **Project does not depend on `flame`** — must not fire; gate on package presence like saropa's other
   ecosystem-specific rules.

---

## Alternatives Considered

- **Flag ANY field assignment in `onMount()`, no exceptions** — rejected; Edge Case 1 (parent-relative
  repositioning) is a legitimate, common `onMount()` use that would produce excessive false positives if
  banned outright. Detection should target constructor-like allocation (`late final` first-assignment,
  `Sprite(...)`/`Component(...)`-style constructions) rather than all field writes.

---

## Decision

---

## Implementation Notes

---

## Commits

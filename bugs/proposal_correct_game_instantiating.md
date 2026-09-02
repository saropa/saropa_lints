# PROPOSAL: Flag Flame Game Instantiated Outside `runApp`/`GameWidget`

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific: `flame`)
Related rules: none

---

## Summary

Add `correct_game_instantiating` to flag a Flame `Game` (or `FlameGame`) subclass instantiated directly (e.g. `MyGame()` stored in a field, built in `build()`, or created ad hoc) instead of being wired through `GameWidget` — the pattern Flame expects for its widget-tree/lifecycle integration.

**Closes gap:** `dart_code_metrics_presets` `correct-game-instantiating` AND `dart_code_linter` `correct_game_instantiating` (same rule, two package names). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Flame" gaps section (both preset packages ship an identical rule under different casing).

---

## Motivation

Flame's `Game` lifecycle (mount, `onLoad`, game loop ticking) is driven by `GameWidget`. Instantiating a `Game` subclass outside that wiring — e.g. inside `build()` on every rebuild, or as a bare field never passed to a `GameWidget` — either recreates the game state repeatedly or produces a game instance that never actually runs, both easy mistakes for developers new to Flame.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = MyGame(); // LINT — Game instantiated inside build(); recreated every rebuild, not wired to GameWidget lifecycle
    return Container();
  }
}
```

### Should pass (good code)

```dart
class GameScreen extends StatelessWidget {
  final MyGame _game = MyGame(); // OK — created once, outside build()

  @override
  Widget build(BuildContext context) {
    return GameWidget(game: _game); // OK — passed to GameWidget
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific rule for `flame`; only relevant to projects that depend on it.

---

## Edge Cases

1. **`Game` instantiated in `initState()` and stored in a `State` field, later passed to `GameWidget`** — should pass; correct lifecycle placement.
2. **`Game` instantiated in a test file to drive it headlessly without a `GameWidget`** — should pass; test files are exempt as `Game` can be driven directly in unit tests.
3. **`Game` instantiated inside `build()` but assigned to a `late final` field guarded by `??=`** — needs discussion; still runs on first build only, arguably safe, but pattern is easy to get wrong across rebuilds if the guard is removed later.
4. **`GameWidget.controlled(gameFactory: MyGame.new)`** — should pass; this is Flame's own recommended factory-based instantiation pattern.

---

## Alternatives Considered

- **Only flag instantiation directly inside `build()`** — rejected in favor of the broader "must eventually reach a `GameWidget`" check to also catch orphaned instances that are never used at all.

---

## Decision

---

## Implementation Notes

Single implementation serves both competitor rule names (`correct-game-instantiating` / `correct_game_instantiating`); no need for two saropa rules.

---

## Commits

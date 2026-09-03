# PROPOSAL: Prefer `ModalRoute.of(context)?.isCurrent` Over Manual Route-Comparison

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `use_context_is_current_modal_route` to flag manual "am I the topmost/active route" checks (comparing `ModalRoute.of(context)` against `Navigator.of(context).widget.pages.last` or tracking a boolean flag via route observers) and suggest the built-in `ModalRoute.of(context)?.isCurrent` getter instead.

**Closes gap:** `flutter_skill_lints` `use_context_is_current_modal_route`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `flutter_skill_lints` gap list.

---

## Motivation

`ModalRoute.isCurrent` is a framework-provided, correctly-maintained boolean that Flutter itself updates on every navigation transition. Developers unfamiliar with it often reinvent it with manual route-stack inspection or a self-managed `bool _isActive` flag updated in navigation callbacks — both approaches are more code, more error-prone (missed edge cases like route replacement or nested navigators), and drift out of sync with the actual navigator state.

---

## Detection / Behavior

Flag a manual "is this the active route" comparison pattern: `Navigator.of(context).widget.pages.last == ...` style comparisons, or a locally-declared field toggled inside `didPush`/`didPopNext`/`didPushNext` route-aware-mixin callbacks that is only ever used to answer "is this route current."

### Should flag (bad code)

```dart
class _ScreenState extends State<Screen> with RouteAware {
  bool _isTop = true;

  @override
  void didPushNext() => setState(() => _isTop = false); // LINT — reinventing ModalRoute.isCurrent

  @override
  void didPopNext() => setState(() => _isTop = true);
}
```

### Should pass (good code)

```dart
class _ScreenState extends State<Screen> {
  @override
  Widget build(BuildContext context) {
    final isTop = ModalRoute.of(context)?.isCurrent ?? false; // OK — built-in getter
    return Text(isTop ? 'Active' : 'Backgrounded');
  }
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Detecting the "manual reimplementation" pattern reliably requires heuristics on `RouteAware` mixin usage that carry real false-positive risk against legitimate `RouteAware` use cases unrelated to top-of-stack tracking.

---

## Edge Cases

1. **`RouteAware` used for analytics/screen-view tracking (not "am I current" logic)** — should pass; only flag when the `bool` field's sole use is answering the is-current question.
2. **`ModalRoute.of(context)?.isCurrent` already used correctly** — should pass.
3. **Nested navigators where "current" needs to be scoped to a specific `Navigator`, not the root** — should discuss; `ModalRoute.of(context)` already resolves to the nearest enclosing route, so this is usually still correct, but worth a correction-message caveat.

---

## Alternatives Considered

---

## Decision

---

## Implementation Notes

---

## Commits

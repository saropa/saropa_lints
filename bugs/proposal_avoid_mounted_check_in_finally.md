# PROPOSAL: Flag `mounted` Checks Placed Inside a `finally` Block

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_mounted_check_after_await` (existing, DCM-parity extension)

---

## Summary

Add `avoid_mounted_check_in_finally` to flag `if (mounted)` / `if (!mounted) return;` checks placed inside a `finally` block following an `await` in `State` lifecycle/callback code — a `finally` block always runs, including after the widget has already been disposed and even along exception paths, so gating a `setState`/navigation call there on `mounted` gives a false sense of safety: the check runs, but by the time it does, other cleanup in the same `finally` may already have executed unconditionally before it.

**Closes gap:** flutter_skill_lints `avoid_mounted_check_in_finally`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`mounted` checks exist to guard against calling `setState()`/`Navigator` operations after a widget's `State` has been disposed following an `await`. Placing that guard inside `finally` is a common but broken pattern: statements in `finally` above the `mounted` check still execute unconditionally regardless of disposal state, and the developer's mental model ("finally always runs, so this is the safe place to check") is backwards — the check needs to happen at the point of use, immediately after each `await`, not bundled into a single end-of-block gate.

---

## Detection / Behavior

Flag an `if` statement testing `mounted` (or `!mounted`) whose nearest enclosing block is a `finally` clause of a `try`/`finally` inside a `State` subclass method.

### Should flag (bad code)

```dart
Future<void> _submit() async {
  setState(() => _isLoading = true);
  try {
    await _api.submit(_formData);
  } finally {
    _controller.dispose(); // Runs unconditionally, even if unmounted
    if (mounted) { // LINT — mounted check in finally gives false confidence
      setState(() => _isLoading = false);
    }
  }
}
```

### Should pass (good code)

```dart
Future<void> _submit() async {
  setState(() => _isLoading = true);
  try {
    await _api.submit(_formData);
  } finally {
    _controller.dispose();
  }
  if (!mounted) return; // OK — checked immediately after the await, at point of use
  setState(() => _isLoading = false);
}
```

---

## Proposed Tier

Tier: Recommended
Justification: A `mounted`-after-`await` bug is a real crash/error risk ("setState called after dispose"); this rule catches a specific misplaced-guard variant of that class of bug, warranting broader default-on placement similar to the existing `require_mounted_check_after_await` rule.

---

## Edge Cases

1. **`mounted` check inside `finally` that gates the *entire* finally body (nothing runs unconditionally above it)** — needs discussion; still recommend flagging by default, since a later edit adding an unconditional statement above the check would silently reintroduce the bug with no lint signal at that edit site.
2. **`if (mounted)` inside `finally` used only to log a diagnostic (no `setState`/navigation)** — should pass; the risk is specifically unsafe widget-tree operations after disposal, not diagnostic checks.
3. **`try`/`finally` with no `await` inside the `try` block** — should pass; the `mounted` concern only applies after crossing an async gap.
4. **`mounted` check in `finally` inside a `StatefulWidget` helper method that is itself called from multiple places, some without a preceding `await`** — should still flag; the pattern is unsafe regardless of caller.

---

## Alternatives Considered

- **Ban `finally` blocks entirely in async `State` methods** — rejected; `finally` is legitimate for unconditional cleanup (disposing controllers, resetting flags) — the rule targets the specific `mounted` guard placement, not `finally` usage in general.

---

## Decision

---

## Implementation Notes

---

## Commits

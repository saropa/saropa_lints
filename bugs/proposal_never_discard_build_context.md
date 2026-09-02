# PROPOSAL: Flag Builder Callbacks That Never Use Their `BuildContext` Parameter

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `use_build_context_synchronously`

---

## Summary

Add `never_discard_build_context` to flag a `BuildContext` parameter supplied by a builder callback (`WidgetBuilder`, `TransitionBuilder`, `Builder(builder: (context) => ...)`, `Consumer`'s `context`, etc.) that is never read inside the callback body. A builder callback exists specifically to hand the caller a *scoped* context — ignoring it and reaching for an outer/ambient context instead usually means the widget loses the intended `InheritedWidget` scope (theme, localization, provider) that the builder was set up to provide.

**Closes gap:** `leancode_lint` `never_discard_build_context` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Builder(builder: (context) => Text(Theme.of(context).primaryColor.toString()))` exists because the outer `context` doesn't yet see the widget being built. When a developer writes the callback but reads a captured outer `context` instead of the parameter, the bug is invisible until the value resolves to the wrong scope at runtime (wrong theme, wrong localization, stale `Provider`/`InheritedWidget` value). Flagging the unused parameter catches the mistake at write time.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  return Builder(
    builder: (innerContext) { // LINT — `innerContext` is declared but never read
      return Text(Theme.of(context).primaryColor.toString()); // uses outer `context` instead
    },
  );
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return Builder(
    builder: (innerContext) {
      return Text(Theme.of(innerContext).primaryColor.toString()); // OK — uses the scoped context
    },
  );
}
```

---

## Proposed Tier

Tier: Recommended
Justification: catches a real, hard-to-spot scoping bug in common Flutter builder patterns without requiring any package beyond Flutter itself.

---

## Edge Cases

1. **Builder body has no need for any `InheritedWidget`/theme lookup at all (e.g. returns a constant widget)** — needs discussion; a context param that is genuinely unusable should be renamed `_` rather than flagged, so the rule should treat `_`-prefixed unused params as intentional and pass.
2. **Nested builders where the inner builder's context is used but the outer's is not** — should flag the outer builder only if its own context parameter goes unused within its own callback body (excluding nested callback bodies).
3. **`StatefulBuilder`'s `setState` parameter combined with an unused `context`** — should still flag the unused `context`; `setState` being used doesn't excuse ignoring `context`.
4. **Context captured into a variable and used later in the same callback** — should pass; the rule checks for any read, not just direct inline use.

---

## Alternatives Considered

- **Require renaming unused context params to `_`** — deferred as a quick fix, not the detection rule itself; detection should fire regardless of whether the offending code is expected to eventually rename or actually use it.

---

## Decision

---

## Implementation Notes

---

## Commits

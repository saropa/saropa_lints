# PROPOSAL: Flag Riverpod App Root Missing ProviderScope

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `missing_provider_scope` to flag a `runApp(...)` call (or equivalent Flutter app entry point) whose argument tree does not include a `ProviderScope` ancestor, when the project depends on `flutter_riverpod`/`hooks_riverpod`. Every `Provider`/`Consumer` read in the widget tree requires a `ProviderScope` somewhere above it in `main()` — omitting it throws `ProviderScope must be added above ... MyApp()` at startup.

**Closes gap:** `many_lints` `missing_provider_scope` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`ProviderScope` is a one-time, easy-to-forget wrapper: it's needed exactly once, at the app root, and its absence produces a crash on the very first frame with no obvious static hint beforehand. Because the fix is mechanical (wrap `runApp`'s argument) and the failure mode is a 100%-reproducible startup crash, this is a high-confidence, high-value static check for any Riverpod project.

---

## Detection / Behavior

Only applies when the project depends on `flutter_riverpod` or `hooks_riverpod`. Flag a `runApp(expr)` invocation in `main()` (or any top-level `main` function) where `expr`'s outermost constructor is not `ProviderScope` and no `ProviderScope` constructor appears anywhere in `expr`'s argument subtree.

### Should flag (bad code)

```dart
void main() {
  runApp(const MyApp()); // LINT — no ProviderScope ancestor; Provider reads inside MyApp will throw
}
```

### Should pass (good code)

```dart
void main() {
  runApp(
    const ProviderScope(
      child: MyApp(), // OK — ProviderScope wraps the app root
    ),
  );
}
```

---

## Proposed Tier

Tier: Essential
Justification: Guarantees crash-on-launch for any Riverpod-using app; matches the bar for saropa's other Essential-tier startup-crash prevention rules.

---

## Edge Cases

1. **`ProviderScope` wrapped several widgets deep instead of directly around `runApp`'s argument (e.g. inside a custom `AppBootstrapper` widget)** — should still pass; detection must walk the constructed widget tree textually/structurally, not require `ProviderScope` to be the literal outermost node, since indirection through a custom bootstrap widget is common.
2. **Test entry points (`testWidgets`, `pumpWidget`) missing `ProviderScope`** — in scope separately; `pumpWidget(const MyApp())` in a widget test has the identical failure mode and should also be flagged, or explicitly noted as future work if out of initial scope.
3. **Multiple `runApp` calls behind a flavor/environment switch, only one missing `ProviderScope`** — each call site is checked independently.
4. **`ProviderScope` present but with `overrides: []` only, no actual scope issue** — should pass; this rule only checks presence, not configuration correctness.

---

## Alternatives Considered

- **Detect via `child: MyApp()` regardless of `runApp`** — rejected; anchoring on `runApp()`'s argument tree is precise and matches exactly the runtime check Riverpod itself performs (`ProviderScope must be an ancestor`).

---

## Decision

---

## Implementation Notes

---

## Commits

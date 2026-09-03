# PROPOSAL: `avoid_unnecessary_safe_area` — Flag Nested `SafeArea` Widgets

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_safe_area_consumer`, `require_safe_area_handling`, `prefer_ios_safe_area`, `prefer_safe_area_aware`

---

## Summary

Flag a `SafeArea` widget whose ancestor chain (within the same widget subtree, no intervening `Scaffold`/full-screen route boundary) already contains another `SafeArea` — the inner `SafeArea` applies its insets a second time against padding the outer one already consumed, wasting space and, in the worst case, double-padding content off the visible area.

**Closes gap:** `flutter_skill_lints` `avoid_unnecessary_safe_area` (github.com/sgaabdu4/flutter_skill_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "flutter_skill_lints" Gaps section.

---

## Motivation

`SafeArea` insets its child by the current `MediaQuery` padding and, by default, *consumes* that padding for its descendants (`MediaQuery.of(context).padding` inside a `SafeArea`'s child is effectively zeroed for the dimensions it handles). A second `SafeArea` nested directly inside the first therefore has nothing left to inset against under normal conditions — it either does nothing, or, in edge cases involving explicit `minimum` padding, adds a `minimum` value the outer `SafeArea` did not intend. This is a copy-paste/composition mistake most commonly seen when a widget that already wraps its content in `SafeArea` (e.g. a shared `AppScaffold`) is placed inside a screen that also wraps its `body` in `SafeArea`. saropa already has closely related rules — `prefer_safe_area_consumer` (`lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:2024`) flags `SafeArea` as the *direct* body of a `Scaffold` that has an `AppBar`/`BottomNavigationBar`, and `require_safe_area_handling` / `prefer_safe_area_aware` push the opposite direction (require `SafeArea` when one is *missing*) — but none of them inspect the widget tree for a `SafeArea` literally nested inside another `SafeArea`, which is the general case flutter_skill_lints targets and is not limited to the `Scaffold.body` position.

---

## Detection / Behavior

### Scoping decision

"Doesn't need safe-area insets" is not statically provable in the general case — a `SafeArea` could sit under a `Dialog`, `BottomSheet`, or platform overlay Flutter already insets, but AST-only analysis cannot reliably determine the presentation context (route type, sheet builder, etc.) without whole-program reasoning. To keep false positives near zero, this rule's initial scope is **only the unambiguous case**: an `InstanceCreationExpression` for `SafeArea` whose `child` argument expression (walking through simple non-branching wrapper widgets like `Padding`, `Center`, `ColoredBox`, single-child `Container`) resolves to another `SafeArea` `InstanceCreationExpression`, with no intervening `Scaffold` or full-screen route boundary between them. The `Dialog`/`BottomSheet`-already-insets case is deferred (see Edge Cases #5) — it requires resolving where the `SafeArea` is actually mounted at runtime (i.e., whether it is passed as a sheet/dialog builder's return value), which is a materially harder detection problem with a much higher false-positive risk if guessed at structurally.

### Should flag (bad code)

```dart
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body});
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: body); // outer SafeArea
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea( // LINT — nested inside AppScaffold's own SafeArea
        child: const Text('Home'),
      ),
    );
  }
}

// Directly nested, no wrapper needed to see it:
Widget build(BuildContext context) {
  return SafeArea(
    child: SafeArea( // LINT — redundant, insets applied twice
      child: const Text('Content'),
    ),
  );
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return SafeArea(
    child: Text('Content'), // OK — single SafeArea
  );
}

// OK — SafeArea(top: false) narrowing a *different* edge than an unrelated
// outer SafeArea is a deliberate composition, not accidental doubling.
Widget build(BuildContext context) {
  return SafeArea(
    bottom: false,
    child: SafeArea(
      top: false,
      left: false,
      right: false,
      child: const Text('Content'),
    ),
  );
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Not a crash or accessibility bug, but a genuine layout defect (wasted/incorrect padding) with a narrow, low-false-positive detection surface (direct nesting only) — sits below Essential (no data-loss/crash risk) but above a purely stylistic tier since it produces visibly wrong spacing.

---

## Edge Cases

1. **`SafeArea` nested inside another `SafeArea` with disjoint edges** (outer handles `bottom`, inner handles `top`/`left`/`right`, as in the Good example) — should pass; this is a deliberate, non-overlapping split and not the doubling bug the rule targets.
2. **Nesting separated by a `Scaffold`** (outer `SafeArea` wraps a widget that itself builds a `Scaffold` with an inner `SafeArea` body) — should pass; a new `Scaffold`/route boundary resets the meaningful insets context, so this is not the same accidental-doubling pattern.
3. **Nesting through an opaque custom widget** (`SafeArea(child: MyCustomWrapper(child: SafeArea(...)))` where `MyCustomWrapper`'s own `build()` is not visible at the call site) — false negative, acceptable; AST-only detection cannot see through an arbitrary widget's `build()` method, consistent with the scoping decision above.
4. **`SafeArea` inside a `Dialog`/`BottomSheet`/`showModalBottomSheet` builder that Flutter already insets** — out of scope for this proposal (see Scoping decision); flagging this class of "already inset by the framework" case is deferred to a follow-up once a reliable way to detect the dialog/sheet builder context is identified.
5. **Both `SafeArea`s have identical explicit edge configuration** (e.g. both default, all edges true) — should flag; this is the clearest possible instance of the redundant-doubling bug.

---

## Alternatives Considered

- **Attempt to prove "doesn't need insets" generally** (any `SafeArea` whose content never reaches a screen edge) — rejected as the initial scope; this requires layout/geometry reasoning no static AST rule can do reliably, and would produce either near-zero recall (too conservative to matter) or high false-positive noise (too aggressive). Direct/near-direct nesting is the one sub-case that is both real-world common (copy-paste, shared-scaffold-plus-per-screen-SafeArea) and staticly provable.
- **Fold into `prefer_safe_area_consumer`** — rejected; that rule's detection is specifically anchored on `Scaffold.body` with `appBar`/`bottomNavigationBar` presence, a different (and narrower) trigger condition than general nested-`SafeArea` detection. Keeping them separate avoids overloading one rule's problem message with two distinct causes.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`, adjacent to `PreferSafeAreaConsumerRule` — reuse its `InstanceCreationExpression` walking pattern and the file's existing simple-wrapper-widget unwrapping helper if one exists, or add a small `_unwrapToChild` helper that walks through `Padding`/`Center`/`ColoredBox`/single-child `Container` to reach the next meaningful widget.

---

## Commits

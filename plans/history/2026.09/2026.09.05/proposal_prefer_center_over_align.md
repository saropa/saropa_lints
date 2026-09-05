# PROPOSAL: Flag `Align(alignment: Alignment.center, ...)` — Use `Center` Instead

**Status: Duplicate — already implemented as `PreferCenterOverAlignRule` in `lib/src/rules/widget/widget_layout_constraints_rules.dart`**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `prefer_center_over_align` to flag `Align` widgets whose `alignment` argument is exactly `Alignment.center` (the default), recommending the dedicated `Center` widget instead — `Center` is a thinner, self-documenting equivalent of `Align(alignment: Alignment.center)` with no functional difference.

**Closes gap:** leancode_lint `prefer_center_over_align` (not currently active upstream in leancode_lint's own ruleset, but a real, well-defined gap). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` leancode_lint Gaps section.

---

## Motivation

`Center` exists in the Flutter SDK specifically as `Align` with `alignment` hardcoded to `Alignment.center` — the two are interchangeable in every respect (layout behavior, widget cost) once `Align`'s alignment is set to center. Spelling it out as `Align(alignment: Alignment.center, ...)` is strictly more verbose with no offsetting benefit, and it obscures intent for a reader who has to check the `alignment` argument to realize the widget is just centering its child.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  return Align(
    alignment: Alignment.center, // LINT — use Center instead of Align(alignment: Alignment.center)
    child: const Text('Hello'),
  );
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return Center(
    child: const Text('Hello'), // OK
  );
}

Widget buildOffset(BuildContext context) {
  return Align(
    alignment: Alignment.topCenter, // OK — genuinely non-center alignment, Align is the right widget
    child: const Text('Hello'),
  );
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: purely stylistic, zero functional/performance difference between the two widgets — belongs at the lowest-priority opt-in tier alongside other "there is a more specific SDK widget for this exact configuration" style rules.

---

## Edge Cases

1. **`Align` with no `alignment` argument at all** — should also flag, since `Alignment.center` is `Align`'s documented default; omitting the argument still produces centering behavior.
2. **`Align(alignment: Alignment.center, widthFactor: 2.0, ...)`** — should pass; `Center` does expose `widthFactor`/`heightFactor` too (it is literally `Align` under the hood with those forwarded), so this case should still flag with a fix that carries `widthFactor`/`heightFactor` over to `Center`.
3. **`alignment` set via a variable/const reference that evaluates to `Alignment.center` but isn't textually `Alignment.center`** — should pass; only flag the literal `Alignment.center` expression to avoid false positives on dynamically computed alignments that happen to equal center at runtime.

---

## Alternatives Considered

- **Quick fix that mechanically rewrites `Align(alignment: Alignment.center, child: X)` to `Center(child: X)`** — include in the initial implementation; the rewrite is purely mechanical for the common no-extra-args case.

---

## Decision

---

## Implementation Notes

---

## Commits

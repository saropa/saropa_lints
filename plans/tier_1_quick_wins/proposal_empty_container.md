# PROPOSAL: Flag `Container()` With No Arguments

**Status: Duplicate — already covered by `AvoidUnnecessaryContainersRule` (`avoid_unnecessary_containers_resolved`) in `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`**

Created: 2026-09-02
Type: New rule
Related rules: `no_empty_block` (distinct — empty block bodies, not empty widget constructors)

---

## Summary

Add `empty_container` to flag a Flutter `Container()` instantiated with zero arguments, which renders as an invisible, zero-size box — almost always a leftover placeholder or a mistake where a child/decoration was meant to be supplied.

**Closes gap:** `essential_lints` `empty_container`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "essential_lints" gaps section.

---

## Motivation

`Container()` with no arguments is functionally a no-op widget (renders nothing, takes no space) and is either scaffolding left in place after refactoring or a sign the developer intended `SizedBox.shrink()` / an actual sized spacer but reached for the wrong constructor. Flagging it nudges toward either removing the dead widget or using the semantically correct, cheaper `SizedBox`/`SizedBox.shrink()`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  return Container(); // LINT — Container() with no arguments renders nothing; remove it or use SizedBox.shrink()
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return const SizedBox.shrink(); // OK — explicit, cheaper empty-space widget
}

Widget build(BuildContext context) {
  return Container(color: Colors.red); // OK — Container has meaningful arguments
}
```

---

## Proposed Tier

Tier: Recommended
Justification: near-certain dead-code/wrong-widget signal with a trivial, always-correct fix; matches saropa's placement for other "you probably meant a different widget" correctness rules.

---

## Edge Cases

1. **`Container(key: someKey)`** — should pass; a key-only `Container` can be a legitimate slot-filling placeholder for widget identity/animation purposes.
2. **`const Container()`** — should flag identically; `const` doesn't change the zero-argument semantics.
3. **`Container()` passed as a list item just to reserve a visual slot in a `Row`/`Column` (spacer pattern)** — should still flag; `SizedBox()`/`SizedBox.shrink()` is the correct, cheaper spacer widget for this exact use case, and the correction message should say so.
4. **Custom subclass named `Container` unrelated to `package:flutter/widgets.dart`** — should pass; must verify the resolved type is Flutter's `Container`, not a project's own class of the same name.

---

## Alternatives Considered

- **Provide a quick fix that auto-replaces with `SizedBox.shrink()`** — accepted as a follow-up scope item; straightforward mechanical replacement, low risk, should be included in the initial implementation if time allows since it satisfies the "fixes must make a real code change" rule cleanly.

---

## Decision

---

## Implementation Notes

Quick fix candidate: replace `Container()` (and `Container(key: ...)` case excluded) with `const SizedBox.shrink()`.

---

## Commits

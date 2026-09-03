# PROPOSAL: Flag Numeric-Only Semantic Label Missing Units

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `none`

---

## Summary

Add `avoid_numeric_only_semantics_label` to flag `Semantics`/`semanticLabel`/`tooltip` strings that are purely numeric (e.g. `'42'`, `'3.5'`) with no accompanying unit or context word. A screen reader announces a bare number with no indication of what it measures ("forty-two" — forty-two what?), whereas sighted users infer meaning from surrounding UI (an icon, a label, a color).

**Closes gap:** `flutter_a11y_lints` `A09` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Numeric badges, counters, and metrics (unread counts, percentages, ratings, prices) are common in Flutter UIs and frequently get a semantic label that is just the raw formatted number, inherited straight from the visible `Text` widget. Sighted users have visual context (a bell icon next to "3" reads as "3 notifications"); screen-reader users hear only "three" with no context. `flutter_a11y_lints`' `A09` targets exactly this gap, which is otherwise invisible without manual VoiceOver/TalkBack testing.

---

## Detection / Behavior

Flag a string literal passed to `label:`/`semanticLabel:`/`tooltip:` whose entire trimmed content matches a numeric pattern (integer, decimal, or percentage with no letters/words) — e.g. `'42'`, `'3.5'`, `'100%'` alone, without any accompanying descriptive word in the same string.

### Should flag (bad code)

```dart
Semantics(
  label: '$unreadCount', // LINT — bare number, no unit/context ("3" announced with no meaning)
  child: Text('$unreadCount'),
);
```

### Should pass (good code)

```dart
Semantics(
  label: '$unreadCount unread messages', // OK — number carries context
  child: Text('$unreadCount'),
);
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Real accessibility gap but with meaningful false-positive risk (legitimate numeric-only labels exist, e.g. a calculator display or code); Comprehensive matches saropa's placement for heuristic accessibility rules that need a deeper pass rather than default-on enforcement.

---

## Edge Cases

1. **Numeric label on a widget whose own accessible role already supplies context** (a `Slider` announcing "value 42 of 100" via its own semantics, not a raw label override) — should pass; only bare literal string labels are in scope, not framework-synthesized announcements.
2. **Percentage strings (`'75%'`)** — should flag same as plain numbers; "%" alone is not sufficient context (75% of what?).
3. **Currency strings (`'$42'`, `'42 USD'`)** with a unit/currency marker — should pass; the currency symbol/code is itself the context.
4. **Calculator/numeric-input display widgets where the number IS the entire content** — needs discussion; likely requires an opt-out (`// ignore:`) rather than a structural exemption, since the rule cannot statically distinguish "meaningful raw number" from "missing context" widgets.

---

## Alternatives Considered

- **Flag any numeric string regardless of surrounding widget** — accepted as the simplest heuristic; deeper widget-context inference (checking sibling `Icon`s) was considered but rejected as too complex/fragile for the payoff.

---

## Decision

---

## Implementation Notes

---

## Commits

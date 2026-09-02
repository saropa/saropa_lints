# PROPOSAL: `Semantics()` Label Replacement Must Exclude Children (Prevent Double Announcement)

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `none`

---

## Summary

Add `require_semantics_exclude_semantics_with_label` to flag `Semantics(label: ..., child: ...)` where the child subtree contains its own text/semantic content (e.g. a `Text` widget, another labeled control) and `excludeSemantics` is not set to `true`. Without `excludeSemantics: true`, the screen reader announces both the custom `label` AND the child's own semantics, producing a double announcement.

**Closes gap:** `flutter_a11y_lints` `A07` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Semantics(label: 'X', child: someWidget)` is meant to *replace* the accessible description of `someWidget` with `'X'`, but by default it merges rather than replaces — the child's own semantics nodes are still present in the tree alongside the custom label. Developers commonly assume `label:` overrides the child, and only discover the double-announcement bug when testing with an actual screen reader, which most CI/dev workflows never do. `flutter_a11y_lints`' `A07` is prior art for statically catching this before it reaches a user with assistive tech.

---

## Detection / Behavior

Flag `Semantics(...)` constructor calls that set a non-null `label:` argument, have a `child:` whose subtree contains inspectable text/semantic content (a `Text`, `Icon` with `semanticLabel`, or nested `Semantics`/labeled widget), and do not also set `excludeSemantics: true`.

### Should flag (bad code)

```dart
Semantics(
  label: 'Unread messages: 3', // LINT — child Text is also announced, causing double-announcement
  child: Row(
    children: [
      const Icon(Icons.mail),
      Text('$unreadCount'),
    ],
  ),
);
```

### Should pass (good code)

```dart
Semantics(
  label: 'Unread messages: 3',
  excludeSemantics: true, // OK — child's own semantics are suppressed
  child: Row(
    children: [
      const Icon(Icons.mail),
      Text('$unreadCount'),
    ],
  ),
);
```

---

## Proposed Tier

Tier: Recommended
Justification: Direct correctness bug for assistive-tech users with a one-argument mechanical fix (`excludeSemantics: true`); undetectable without a real screen reader, making static coverage high-value.

---

## Edge Cases

1. **`child:` is a leaf widget with no text content** (a plain `Container`, `SizedBox`) — should pass; nothing to double-announce.
2. **`label:` is null or empty** — should pass; the rule only applies when a replacement label is actually being supplied.
3. **`Semantics` used purely for `hint:`/`value:` without `label:`** — should pass; only `label:` combined with a content-bearing child triggers this pattern.
4. **Deeply nested child subtree where content is several widgets down** — flag if statically detectable via AST descent through common layout wrappers (`Row`, `Column`, `Padding`, `Center`); pass (no false negative penalty, but no crash) when the child is an opaque custom widget the analyzer cannot see into.

---

## Alternatives Considered

- **Auto-fix that always inserts `excludeSemantics: true`** — considered as the rule's quick fix; safe because it is exactly the documented correct usage, not a guess.

---

## Decision

---

## Implementation Notes

---

## Commits

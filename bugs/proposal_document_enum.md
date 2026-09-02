# PROPOSAL: Require DartDoc on Enums and Enum Values

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `document_interface` (proposed alongside), `document_fake_parameters` (proposed alongside)

---

## Summary

Add `document_enum` to flag public `enum` declarations and their individual enum values (constants) that lack a DartDoc comment, mirroring the same discoverability expectation saropa already applies to public classes/methods but currently misses for enums.

**Closes gap:** `ripplearc_linter` `document_enum`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Documentation conventions" section.

---

## Motivation

Enum values are public API surface exactly like class members, but IDE tooltips and pub.dev API docs only show useful information when a DartDoc comment exists. Undocumented enum values are common because they read as "self-explanatory" at write time but leave future readers guessing at intent, valid ranges, or when to choose one value over another.

---

## Detection / Behavior

### Should flag (bad code)

```dart
enum OrderStatus { // LINT — public enum missing DartDoc
  pending,
  shipped, // LINT — enum value missing DartDoc
  cancelled,
}
```

### Should pass (good code)

```dart
/// Lifecycle states for a customer order.
enum OrderStatus {
  /// Order has been placed but not yet shipped.
  pending,

  /// Order has left the warehouse.
  shipped,

  /// Order was cancelled before shipping.
  cancelled,
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: documentation-completeness rule, high-volume but low-severity; matches saropa's placement for other blanket "public API must be documented" style rules.

---

## Edge Cases

1. **Private enum (`enum _Internal`)** — should pass; not public API.
2. **Enum value whose name is fully self-describing (e.g. `true`/`false`-style booleans)** — should flag anyway; consistency over per-value judgment calls, matches DCM/ripplearc precedent of "always require, no exceptions."
3. **Enhanced enum with documented members but undocumented values (or vice versa)** — each documentation target (enum itself, each value) is checked independently.
4. **Generated enums (`.g.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Only require documentation on the enum declaration, not each value** — rejected; individual enum values are the part developers most need explained (what does `pending` vs `shipped` actually mean), so skipping them defeats the purpose.

---

## Decision

---

## Implementation Notes

Can likely share the existing "has DartDoc" detection helper already used by any current public-API documentation rule, if one exists — check `lib/src/rules/` for a `public_member_api_docs`-style helper before writing a new DartDoc-presence check.

---

## Commits

# PROPOSAL: Suggest Cascade Notation for Repeated Calls on a Freshly Constructed Instance

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `cascade_invocations` (core lints)

---

## Summary

Add `new_instance_cascade` to flag two or more consecutive statements that each call a method or set a property on the same freshly-constructed local variable, where Dart's cascade (`..`) notation would express the same intent as a single chained expression.

**Closes gap:** `essential_lints` `new_instance_cascade` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Repeating a receiver variable name across several consecutive statements right after construction is pure noise — the reader already knows what `controller` is from the line above and re-reads its name three more times for no new information. Dart's cascade operator collapses this into one expression that reads as "build this object, then configure it", which is both shorter and makes the shared receiver visually obvious.

---

## Detection / Behavior

### Should flag (bad code)

```dart
final controller = TextEditingController();
controller.text = 'hello'; // LINT — repeated calls on freshly-constructed `controller`
controller.selection = const TextSelection.collapsed(offset: 5);
```

### Should pass (good code)

```dart
final controller = TextEditingController()
  ..text = 'hello' // OK — cascade groups the configuration calls
  ..selection = const TextSelection.collapsed(offset: 5);
```

---

## Proposed Tier

Tier: Pedantic
Justification: purely stylistic preference between two equally correct forms; belongs in the opt-in tier alongside other cascade/chaining style rules.

---

## Edge Cases

1. **A statement between the calls that reads the variable's return value or reassigns another variable** — should pass; cascades can't interleave with unrelated statements that consume an intermediate result.
2. **Only one statement calls the receiver after construction** — should pass; cascade adds no value for a single call.
3. **Receiver reassigned between the construction and the calls** — should pass; not a fresh-instance cascade opportunity anymore.
4. **Calls span an `if`/`for` control-flow block** — should pass; cascade cannot cross control-flow boundaries.

---

## Alternatives Considered

- **Also flag single-statement cases where the constructor call itself could inline a cascade of length 1** — rejected; no readability benefit for a single call, and it would fire far too often for a purely cosmetic gain.

---

## Decision

---

## Implementation Notes

---

## Commits

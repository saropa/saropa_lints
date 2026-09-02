# PROPOSAL: Enforce Consistent Named-Argument Order at Call Sites

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `named_parameters_ordering` to flag call sites where named arguments are passed in an order that does not match the order the named parameters are declared in the function/constructor signature. Requiring call-site order to mirror declaration order makes diffs smaller and call sites easier to scan against the API they invoke.

**Closes gap:** `solid_lints` `named_parameters_ordering` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Dart lets named arguments appear in any order, so two call sites for the same constructor can list the same arguments in unrelated orders — one alphabetical, one by "importance", one arbitrary. That inconsistency makes it harder to visually diff two call sites or to match a call site back to the parameter list while reading. Enforcing declaration order gives one canonical shape for every call.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Config {
  Config({required this.host, required this.port, this.timeout});
  final String host;
  final int port;
  final Duration? timeout;
}

final config = Config(
  port: 443,
  host: 'example.com', // LINT — `port` passed before `host`, but `host` is declared first
);
```

### Should pass (good code)

```dart
final config = Config(
  host: 'example.com', // OK — matches declaration order
  port: 443,
  timeout: const Duration(seconds: 5),
);
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure call-site style with no runtime effect; belongs alongside other cosmetic ordering rules in the opt-in Pedantic tier.

---

## Edge Cases

1. **Some named parameters omitted at the call site** — should pass as long as the ones present preserve their relative declaration order.
2. **Constructor declared across `super(...)` forwarding with reordered params** — should flag on the call site only, not the forwarding declaration itself.
3. **Redirecting/factory constructors with a different parameter order than the target** — needs discussion; likely evaluate against the immediate signature being called, not the redirect target.
4. **Named parameters interleaved with positional parameters** — should pass for positional ordering (out of scope); only named-argument relative order is checked.

---

## Alternatives Considered

- **Enforce alphabetical order instead of declaration order** — rejected; alphabetical order breaks logical grouping in wide constructors (e.g. related `min`/`max` pairs), whereas declaration order is already the author's intended grouping.

---

## Decision

---

## Implementation Notes

---

## Commits

# PROPOSAL: Enforce @mustBeAnonymous Callback Arguments Are Passed as Literals

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `must_be_strong_ref`

---

## Summary

Add `must_be_anonymous` to flag a parameter annotated (by `df_safer_dart_lints`'s convention, e.g. `@mustBeAnonymous`) that is passed a tear-off or a stored method/function reference instead of an anonymous function literal (`() { ... }` / `(x) => ...`). Some APIs (disposal callbacks, one-shot listeners, certain Flutter callback slots) require a fresh closure at each call site so identity-based removal/comparison and lifecycle tracking work correctly — passing a shared tear-off breaks that guarantee.

**Closes gap:** `df_safer_dart_lints` `must_be_anonymous` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Certain callback-accepting APIs are documented/annotated as requiring a distinct closure per call site — often because the framework uses object identity to track, deduplicate, or clean up the callback later, and a shared method tear-off (which may be `==`-equal across calls, or retained longer than intended by whatever holds the tear-off) silently defeats that mechanism. Because the annotation encodes an API author's explicit contract, this is a targeted, low-false-positive check: flag only annotated parameter positions, not callbacks generally.

---

## Detection / Behavior

Flag an argument expression passed to a parameter annotated `@mustBeAnonymous` when the argument is not itself a function-literal expression (`FunctionExpression`) — i.e. it's a method tear-off, a stored `Function`/callback variable, or a static/top-level function reference.

### Should flag (bad code)

```dart
class Store {
  void _onDispose() { /* ... */ }

  void register(Lifecycle lifecycle) {
    lifecycle.addCallback(_onDispose); // LINT — tear-off passed where @mustBeAnonymous requires a literal
  }
}
```

### Should pass (good code)

```dart
class Store {
  void _onDispose() { /* ... */ }

  void register(Lifecycle lifecycle) {
    lifecycle.addCallback(() => _onDispose()); // OK — anonymous literal wraps the call
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific to `df_safer_dart_lints`'s annotation convention; only fires on explicitly annotated parameters, so it's precise but narrow — appropriate for a deeper safety pass rather than Essential/Recommended defaults.

---

## Edge Cases

1. **Argument is a function literal that itself calls a tear-off internally (`() => _onDispose()`)** — should pass; the literal wrapper is exactly what the annotation requires, regardless of what's inside it.
2. **Argument is `null` for a nullable `@mustBeAnonymous` parameter** — should pass; no closure identity concern when nothing is passed.
3. **Argument is a local variable holding a function literal assigned earlier (`final cb = () {}; api(cb)`)** — needs discussion; the *value* is technically an anonymous function, but reusing the same closure instance across multiple call sites may still violate the "distinct per call" intent — likely should still flag since the variable could be reused.
4. **Annotation applied to a parameter whose type isn't a function type (misuse of the annotation)** — out of scope for this rule; a separate validity check on the annotation's own placement would be a different rule.

---

## Alternatives Considered

---

## Decision

---

## Implementation Notes

---

## Commits

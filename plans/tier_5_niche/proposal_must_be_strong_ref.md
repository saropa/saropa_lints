# PROPOSAL: Enforce @mustBeStrongRef Fields/Parameters Are Not Held Weakly

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `must_be_anonymous`

---

## Summary

Add `must_be_strong_ref` to flag a field, parameter, or variable annotated (by `df_safer_dart_lints`'s convention, e.g. `@mustBeStrongRef`) that is assigned or wrapped from a `WeakReference<T>`, `Expando`, or otherwise held in a way that permits garbage collection before the API's contract expects it to still be alive. Some APIs document that a given reference must be kept strongly reachable for correctness (e.g. an active subscription, listener, or a resource whose lifetime is externally tracked) — holding it weakly reintroduces a use-after-GC bug that's invisible until the object happens to be collected.

**Closes gap:** `df_safer_dart_lints` `must_be_strong_ref` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Weak references are a common (and often correct) tool for avoiding retention cycles, but they are wrong wherever an API needs the referenced object to remain alive for as long as the API itself is active — a `StreamSubscription`, a registered callback owner, or similar. Because "should this be weak or strong" is a semantic decision the API author already made and documented via the annotation, this rule turns that documented contract into a static, enforced guarantee rather than relying on every caller reading the docs.

---

## Detection / Behavior

Flag an assignment to a field/variable/parameter annotated `@mustBeStrongRef` whose right-hand side is a `WeakReference<T>` construction, an `Expando` lookup, or a value statically typed as `WeakReference<T>`.

### Should flag (bad code)

```dart
class SubscriptionHolder {
  @mustBeStrongRef
  late final StreamController controller;

  void attach(StreamController c) {
    controller = WeakReference(c) as dynamic; // LINT — @mustBeStrongRef field assigned a weak reference
  }
}
```

### Should pass (good code)

```dart
class SubscriptionHolder {
  @mustBeStrongRef
  late final StreamController controller;

  void attach(StreamController c) {
    controller = c; // OK — held strongly, as the annotation requires
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific to `df_safer_dart_lints`'s annotation convention; precise (annotation-gated) but narrow, appropriate for a deeper memory-safety pass rather than default tiers.

---

## Edge Cases

1. **Field typed as `WeakReference<T>` itself (the type, not just the assigned value)** — should flag at the type annotation too, not only at assignment sites; the field's declared type being weak is itself the violation.
2. **Value passed through a helper that internally strengthens a weak reference before storing (`WeakReference(x).target!`)** — should pass; the final assigned value is a strong reference even though a `WeakReference` appears in the expression.
3. **Annotation on a parameter (not a field) — value only weakly referenced transiently inside the method body, never stored** — needs discussion; if the annotation's contract is about storage lifetime, a purely local, non-escaping weak wrapper might be acceptable — scope needs clarifying with the source package's actual semantics before implementation.
4. **Generated code** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

---

## Decision

---

## Implementation Notes

---

## Commits

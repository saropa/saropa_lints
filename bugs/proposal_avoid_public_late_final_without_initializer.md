# PROPOSAL: Flag Public `late final` Fields Without an Initializer

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_disposing_late_fields` (existing), `avoid_unassigned_late_fields` (existing, DCM-parity extension)

---

## Summary

Add `avoid_public_late_final_without_initializer` to flag `late final` fields declared with public visibility (no leading underscore) and no inline initializer — a public `late final` field with no initializer is an implicit contract that *something outside the class* must assign it exactly once before first read, but nothing in the public API signature communicates when or how that assignment must happen, making it a `LateInitializationError` waiting for any external caller who reads it too early.

**Closes gap:** flutter_skill_lints `avoid_public_late_final_without_initializer`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`late final` on a *private* field is a well-understood, self-contained pattern: the class controls all assignment sites internally and the risk of reading-before-assigning is fully auditable within the file. On a *public* field, the class has no control over when external code first reads it — the "must be assigned before use" contract is invisible from the outside, unlike a constructor parameter (visible in the signature) or a nullable field (visible in the type), making this one of the easiest-to-hit runtime crashes in Dart with the least compile-time warning.

---

## Detection / Behavior

Flag any `late final` field declaration with public (non-underscore-prefixed) name and no inline initializer expression.

### Should flag (bad code)

```dart
class UploadTask {
  late final String uploadId; // LINT — public, late final, no initializer: unsafe external contract
}
```

### Should pass (good code)

```dart
class UploadTask {
  UploadTask({required this.uploadId});

  final String uploadId; // OK — required constructor parameter, contract is visible
}

class _InternalCache {
  late final String _computedKey; // OK — private, class controls all assignment sites
}
```

---

## Proposed Tier

Tier: Recommended
Justification: `LateInitializationError` from a public field is a real, easy-to-hit runtime crash with no compile-time signal; default-on placement matches saropa's existing `late`-field safety rules.

---

## Edge Cases

1. **Public `late final` field assigned exactly once, unconditionally, in every constructor's initializer list (functionally equivalent to `final`)** — should flag anyway; if it's always assigned in every constructor, it should just be a `final` field with a constructor parameter, which is strictly safer and equally expressive.
2. **Public `late final` field assigned by a builder/factory pattern deliberately after construction, by design (e.g. two-phase init required by a plugin lifecycle)** — needs discussion; this is the strongest legitimate use case. Recommend documenting the pattern and allowing suppression with justification rather than exempting it in the rule, since two-phase init is inherently the exact risk this rule flags.
3. **Public `late final` field on an abstract class meant to be assigned by subclasses** — should flag the same; subclass assignment is still an invisible-from-outside contract for any external caller of the concrete type.
4. **`late` (not `late final`) public field with no initializer** — out of scope for this rule; mutable `late` fields have a different (also concerning, but separate) risk profile and are better covered by a distinct rule if one doesn't already exist.

---

## Alternatives Considered

- **Flag ALL `late final` fields without an initializer, public or private** — rejected; private `late final` is a well-understood, contained pattern (see saropa's existing `avoid_disposing_late_fields`/`avoid_unassigned_late_fields` rules) and flagging it too would create excessive noise on a pattern that isn't the specific risk this rule targets.

---

## Decision

---

## Implementation Notes

---

## Commits

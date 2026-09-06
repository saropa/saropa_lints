# PROPOSAL: Flag DartDoc Comments on Private (Internal) Methods

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `no_optional_operators_in_tests`

---

## Summary

Add `no_internal_method_docs` to flag `///` DartDoc comments attached to private (leading-underscore) methods and functions. DartDoc is a public-API documentation format published to `dartdoc`/pub.dev pages; private members never appear there, so a `///` comment on one is either dead documentation or a sign the method should be public.

**Closes gap:** `ripplearc_linter` `no_internal_method_docs` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

DartDoc comments carry an implicit promise: "this is part of the contract external callers rely on." Writing one on a private method either misleads a reader into treating internal implementation detail as a stable contract, or it's dead weight nobody will ever render. A plain `//` comment explaining *why* the internal method exists is the right tool for implementation-detail documentation — DartDoc is not.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Parser {
  /// Parses the raw header bytes into a [Header]. // LINT — DartDoc on a private method, never published
  Header _parseHeader(List<int> bytes) => Header.fromBytes(bytes);
}
```

### Should pass (good code)

```dart
class Parser {
  // Parses the raw header bytes; kept private since callers only need parse().
  Header _parseHeader(List<int> bytes) => Header.fromBytes(bytes);
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: purely a documentation-convention nit with zero behavioral or correctness impact.

---

## Edge Cases

1. **Private method inside a class annotated `@visibleForTesting`/exposed via a public wrapper** — should still flag; the method itself remains private regardless of test visibility.
2. **DartDoc `///` comment that only contains a `{@template}`/`{@macro}` reused elsewhere by public members** — needs discussion; template blocks are a legitimate DartDoc mechanism even when the immediate host is private.
3. **Private top-level function (not a class member)** — should flag under the same rationale; DartDoc on any private declaration is unpublished.
4. **A `///` comment on a private method inside a `library`-private file where the whole file is intentionally undocumented** — should still flag; the rule concerns comment *style* (`///` vs `//`), not whether documentation should exist at all.

---

## Alternatives Considered

- **Auto-fix by converting `///` to `//`** — worth pursuing as a quick fix once the rule ships; deferred from this proposal to keep scope to detection.

---

## Decision

---

## Implementation Notes

---

## Commits

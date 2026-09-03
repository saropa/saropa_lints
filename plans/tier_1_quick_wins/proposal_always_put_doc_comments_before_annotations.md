# PROPOSAL: Require Doc Comments Before Annotations, Not After

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `none`

---

## Summary

Add `always_put_doc_comments_before_annotations` to flag a member (class, method, field) where a `///` doc comment is written *after* one or more annotations (`@override`, `@immutable`, `@Deprecated(...)`, etc.) instead of before them. Dart's dartdoc tooling only recognizes a doc comment as attached to a declaration when it immediately precedes the declaration; a doc comment placed between annotations and the declaration, or after the last annotation but written as if documenting the annotation, can end up not associated with the member at all in generated docs.

**Closes gap:** `pyramid_lint` `always_put_doc_comments_before_annotations` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`dart doc` and most Dart tooling expects the ordering `/// doc comment` then `@annotation` then `declaration` — annotations are treated as part of the declaration's "signature," and a doc comment must sit above all of them to be picked up. Writing annotations first and the doc comment second (`@override\n/// Does X.\nvoid foo() {}`) is a common ordering mistake that silently produces undocumented members in generated API docs, with no compiler warning. `pyramid_lint` ships this as a purely mechanical ordering check.

---

## Detection / Behavior

Flag a class/method/field/getter/setter declaration that has both a doc comment (`///`) and at least one annotation, where the doc comment's token position is after any annotation's token position (rather than before all annotations).

### Should flag (bad code)

```dart
class Widget {
  @override
  /// Builds the widget tree. // LINT — doc comment must come before @override, not after
  Widget build(BuildContext context) => const SizedBox();
}
```

### Should pass (good code)

```dart
class Widget {
  /// Builds the widget tree.
  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Purely cosmetic/documentation-generation correctness with a mechanical reorder fix; not a runtime bug, fits saropa's placement for doc-quality rules that most projects would enable during a documentation-hardening pass rather than by default.

---

## Edge Cases

1. **Declaration has multiple annotations and the doc comment is between two of them** (e.g. `@Deprecated(...)\n/// doc\n@override\n...`) — should flag; the doc comment must precede ALL annotations, not just some.
2. **No doc comment present, only annotations** — should pass; nothing to reorder.
3. **Doc comment present, no annotations** — should pass; ordering is trivially satisfied.
4. **Doc comment is a regular `//` comment, not `///`** — should pass; the rule targets dartdoc-recognized `///` comments specifically, since plain `//` comments are never picked up by dartdoc regardless of position.

---

## Alternatives Considered

- **Autofix that reorders automatically** — proposed as the rule's quick fix; safe purely-textual reorder (move the doc-comment token block above the annotation token block) with no semantic risk.

---

## Decision

---

## Implementation Notes

---

## Commits

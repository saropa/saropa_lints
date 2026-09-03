# PROPOSAL: Require DartDoc on Abstract Classes and Their Public Methods

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `document_enum` (proposed alongside), `document_fake_parameters` (proposed alongside)

---

## Summary

Add `document_interface` to flag public abstract classes (Dart's interface convention) and their public abstract/interface methods that lack a DartDoc comment.

**Closes gap:** `ripplearc_linter` `document_interface`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Documentation conventions" section.

---

## Motivation

Abstract classes are Dart's interface mechanism, and their DartDoc is the contract every implementer and caller relies on — what a method promises to do, its preconditions, and what implementers must guarantee. An undocumented interface forces every implementer to reverse-engineer intent from usage sites rather than from the contract itself.

---

## Detection / Behavior

### Should flag (bad code)

```dart
abstract class UserRepository { // LINT — public abstract class missing DartDoc
  Future<User?> findById(String id); // LINT — interface method missing DartDoc
}
```

### Should pass (good code)

```dart
/// Persists and retrieves [User] records from the backing data source.
abstract class UserRepository {
  /// Returns the user with [id], or null if no such user exists.
  Future<User?> findById(String id);
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: documentation-completeness rule for abstract-class contracts; consistent with `document_enum`'s tier placement for the same category of gap.

---

## Edge Cases

1. **Private abstract class (`abstract class _Base`)** — should pass; not public API.
2. **Abstract class with `@override` methods overriding an already-documented supertype method** — should pass; documentation is inherited per standard DartDoc convention (`{@macro}`/dartdoc inheritance), avoids requiring duplicate comments.
3. **Abstract class used purely as a mixin base with no instance methods** — should still flag the class-level doc; no methods to check individually.
4. **Sealed class / class hierarchy used for pattern matching rather than a traditional interface** — needs discussion; may warrant excluding `sealed` from this rule if it overlaps with a more specific sealed-class documentation convention already in saropa.

---

## Alternatives Considered

- **Fold into saropa's general public-API documentation rule instead of a dedicated rule** — rejected if no such general rule currently exists project-wide; if one does exist, this proposal should be reconsidered as a targeted extension rather than a new standalone rule (verify at implementation time).

---

## Decision

---

## Implementation Notes

Check for DartDoc inheritance edge cases carefully — Dart's `@override` methods do not require restating the doc if the supertype method is documented; false positives here would be high-friction.

---

## Commits

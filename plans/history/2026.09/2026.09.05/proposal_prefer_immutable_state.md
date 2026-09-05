# PROPOSAL: Flag Mutable Fields on Name-Pattern-Matched State Classes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_extend_equatable`, `prefer_immutable_bloc_state` (if present), Bloc/Riverpod/Provider state-suffix rules

---

## Summary

Add `prefer_immutable_state` to flag a non-`final` (mutable) field on a class whose name matches a "state" naming convention (suffix `State`, `Model`, `ViewModel`, or a class implementing/extending a known state-holder base type name pattern), independent of which specific state-management package is in use — a state-management-agnostic variant of the Bloc-specific `@immutable`-state checks saropa already has.

**Closes gap:** many_lints `prefer_immutable_state` (state-management-agnostic). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` many_lints non-themed gaps.

---

## Motivation

State objects — regardless of whether the project uses Bloc, Riverpod, Provider, or a hand-rolled state class — are meant to be replaced wholesale on each state transition, not mutated in place. A mutable field on a state class invites in-place mutation that bypasses whatever notification mechanism (emit/notifyListeners/ref invalidation) the surrounding framework relies on to trigger a rebuild, producing a UI that silently goes stale. saropa's existing Bloc-specific rules (`prefer_immutable_bloc_state`, etc.) already cover the Bloc case; this rule generalizes the same check by *name pattern* rather than by package-specific base class, so it also catches hand-rolled `ViewModel`/`*State` classes that don't extend any recognized package base type.

---

## Detection / Behavior

Flag a non-`final`, non-`late final` instance field declared on a class whose name ends in `State`, `Model`, or `ViewModel` (configurable suffix list), excluding classes already covered by a more specific existing saropa rule (Bloc `State` subclasses, which `prefer_immutable_bloc_state` already governs, to avoid double-flagging the same field under two rule ids).

### Should flag (bad code)

```dart
class ProfileViewModel {
  ProfileViewModel({required this.name});
  String name; // LINT — mutable field on a state-pattern class; make it final
}
```

### Should pass (good code)

```dart
class ProfileViewModel {
  const ProfileViewModel({required this.name});
  final String name; // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: name-pattern-based heuristic (not a resolved-type check), so carries a higher false-positive/false-negative risk than saropa's package-specific immutability rules — placed at Comprehensive to keep it opt-in until the naming heuristic is validated against real codebases, rather than Essential/Recommended.

---

## Edge Cases

1. **Class already covered by a more specific saropa rule (`BlocState`, Riverpod `Notifier`, etc.)** — should NOT flag; defer to the existing specific rule to avoid duplicate diagnostics for the same field.
2. **Field that is intentionally mutable for local widget-only caching, on a class that merely happens to end in `Model` (e.g. a data-transfer `UserModel` used only for JSON parsing, not app state)** — false-positive risk inherent to name-pattern matching; document this clearly as a known limitation, and support a `// ignore:` with a one-line justification as the standard escape hatch.
3. **`late final` fields (assigned once, then immutable)** — should pass; `late final` satisfies the same "cannot be reassigned after first set" guarantee `final` does.
4. **Private mutable field with a `final` public getter (encapsulated mutation)** — should still flag the underlying private field, since external immutability doesn't guarantee the object itself won't drift from what a `copyWith`/`emit` cycle expects; needs discussion if this produces excessive noise on well-encapsulated code.

---

## Alternatives Considered

- **Require the class to be resolved against a known state-management base type instead of name-pattern matching** — rejected as the primary approach because that's exactly what saropa's existing package-specific rules already do; the point of this proposal is filling the gap for state classes that *don't* extend a recognized base type, which necessarily requires a name-based heuristic instead of type resolution.

---

## Decision

---

## Implementation Notes

---

## Commits

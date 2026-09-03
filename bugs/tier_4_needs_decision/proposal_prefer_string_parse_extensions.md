# PROPOSAL: Flag `int.tryParse`/`double.tryParse` Null Handling — Use fpdart's `Option`-Returning Parse Extensions Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_safe_collection_access`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_string_parse_extensions` to flag `int.tryParse(s)`/`double.tryParse(s)`/`num.tryParse(s)` used in a codebase that has opted into fpdart, recommending fpdart's `Option`-returning string-parse extensions (e.g. `s.parseIntOption()`) instead, so a parse failure is represented as `None` and composes with the rest of an `Option`/`Either` pipeline instead of requiring a manual null check.

**Closes gap:** many_lints `prefer_string_parse_extensions` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

Same rationale as `prefer_safe_collection_access`: `int.tryParse` returns nullable `int?`, which is a valid escape hatch back to null-based error signaling in a codebase that has otherwise standardized on `Option`/`Either` for representing "this might not have worked." Using the fpdart parse extension keeps the failure mode consistent with the rest of the fpdart-typed pipeline it feeds into.

---

## Detection / Behavior

Flag `int.tryParse(...)`/`double.tryParse(...)`/`num.tryParse(...)` calls whose result flows into an fpdart-typed context (assigned to an `Option`/`Either` variable, passed to an fpdart combinator, or used inside a function whose return type is `Option`/`Either`/`TaskEither`).

### Should flag (bad code)

```dart
Option<int> parseAge(String input) {
  final parsed = int.tryParse(input); // LINT — use input.parseIntOption() inside Option-returning code
  return parsed == null ? const None() : Some(parsed);
}
```

### Should pass (good code)

```dart
Option<int> parseAge(String input) {
  return input.parseIntOption(); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific idiom, scoped to functional-pipeline code; matches the rest of the fpdart family's tier placement.

---

## Edge Cases

1. **`int.tryParse` used outside any `Option`/`Either`-returning context** — should pass; the rule is scoped to fpdart-typed flows, mirroring `prefer_safe_collection_access`'s scoping to avoid blanket-flagging ordinary parsing in non-fpdart code.
2. **`int.parse` (throwing variant, not `tryParse`)** — out of scope for this rule; a separate concern (`avoid_dynamic` / general throwing-parse rules) already covers unguarded `int.parse`.
3. **Combined with `prefer_from_nullable`'s manual null-check pattern immediately after `tryParse`** — both rules may fire on the same statement (one on the parse call, one on the wrapping ternary); each fix is independently valid, and applying `prefer_string_parse_extensions`'s fix first naturally removes the target for `prefer_from_nullable`.

---

## Alternatives Considered

- **Flag every `tryParse` call project-wide** — rejected; too broad outside fpdart-adopting code, mirrors the same reasoning as `prefer_safe_collection_access`.

---

## Decision

---

## Implementation Notes

---

## Commits

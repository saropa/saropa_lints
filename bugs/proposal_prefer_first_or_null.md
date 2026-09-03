# PROPOSAL: Flag `list.isEmpty ? null : list.first` — Use `list.firstOrNull` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_first`, `prefer_last`

---

## Summary

Add `prefer_first_or_null` to flag the manual `list.isEmpty ? null : list.first` (or `list.isNotEmpty ? list.first : null`) ternary pattern, recommending Dart's built-in `Iterable.firstOrNull` extension (from `dart:core`, via `package:collection` on older SDKs) instead.

**Closes gap:** dart_code_linter `prefer-first-or-null`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` dart_code_linter Gaps section.

---

## Motivation

`firstOrNull` is a one-word, already-available replacement for a two-branch ternary that duplicates the `list`/`isEmpty` reference and is easy to get backwards (checking `isEmpty` but returning `.last` by copy-paste mistake, or inverting the condition). The manual form adds no clarity over the built-in and is strictly more error-prone to write and modify.

---

## Detection / Behavior

### Should flag (bad code)

```dart
int? firstEven(List<int> values) {
  final evens = values.where((v) => v.isEven).toList();
  return evens.isEmpty ? null : evens.first; // LINT — use evens.firstOrNull
}
```

### Should pass (good code)

```dart
int? firstEven(List<int> values) {
  final evens = values.where((v) => v.isEven).toList();
  return evens.firstOrNull; // OK
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: purely stylistic, zero functional difference — the built-in and manual forms behave identically; matches saropa's placement for other "there is a built-in extension for this exact expression shape" style rules.

---

## Edge Cases

1. **Condition written as `list.isNotEmpty ? list.first : null`** — should flag identically; direction-agnostic detection.
2. **Ternary using `.length == 0`/`.length > 0` instead of `.isEmpty`/`.isNotEmpty`** — should still flag; equivalent condition shape (saropa likely already has a separate `prefer_is_empty` rule to normalize this first, but this rule should not require that normalization as a precondition).
3. **The two `list` references in the ternary refer to different receivers (copy-paste mistake, e.g. `a.isEmpty ? null : b.first`)** — should NOT flag; this is not the safe `firstOrNull` shape, and flagging it would suggest an incorrect rewrite that silently changes behavior.
4. **Ternary that returns something other than `.first`/`null` in the two branches (e.g. a default value instead of `null`)** — should not flag this rule; that's a different pattern (`.firstWhere(orElse: ...)`), out of scope here.

---

## Alternatives Considered

- **Auto-fix that rewrites the ternary to `.firstOrNull`** — include in the initial implementation; the rewrite is purely mechanical once the receiver-identity edge case is confirmed safe.

---

## Decision

---

## Implementation Notes

---

## Commits

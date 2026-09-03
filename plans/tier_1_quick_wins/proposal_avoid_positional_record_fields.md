# PROPOSAL: Flag Positional Record Field Access (`$1`, `$2`) in Favor of Named Fields

**Status: Duplicate — already implemented as `AvoidPositionalRecordFieldAccessRule` (`avoid_positional_record_field_access`) in `lib/src/rules/data/record_pattern_rules.dart`**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_positional_record_fields` to flag Dart record types and their access sites that use only positional fields (`(String, int)`, accessed via `.$1`/`.$2`) instead of named record fields (`({String name, int age})`, accessed via `.name`/`.age`) — positional access via `$1`/`$2` carries no semantic meaning at the call site and forces a reader to trace back to the record's declaration to know what each position represents.

**Closes gap:** flutter_skill_lints `avoid_positional_record_fields`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Records are Dart's lightweight anonymous-tuple type, and named fields are directly supported at zero extra cost — `({String name, int age})` is exactly as cheap to declare as `(String, int)`. Using positional fields means every access site reads `pair.$1`, `pair.$2`, which is unreadable outside the immediate context of the declaration and easy to get backwards (swap two same-typed positions silently) since the compiler can't catch a transposition the way it can catch a misspelled named field.

---

## Detection / Behavior

Flag a record type annotation (in a variable declaration, function return type, or parameter type) that declares two or more positional fields with no named fields, and/or a `PropertyAccess`/`PrefixedIdentifier` reading a positional record field (`.$1`, `.$2`, etc.) from an expression whose static type is a record.

### Should flag (bad code)

```dart
(String, int) parseEntry(String line) { // LINT — positional record fields
  final parts = line.split(':');
  return (parts[0], int.parse(parts[1]));
}

void printEntry((String, int) entry) {
  print('${entry.$1}: ${entry.$2}'); // LINT — positional field access
}
```

### Should pass (good code)

```dart
({String name, int age}) parseEntry(String line) { // OK — named record fields
  final parts = line.split(':');
  return (name: parts[0], age: int.parse(parts[1]));
}

void printEntry(({String name, int age}) entry) {
  print('${entry.name}: ${entry.age}'); // OK — self-documenting field access
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Style/readability rule for a relatively recent Dart 3 language feature; appropriate for a deep code-quality pass rather than default-on, given the language feature's newness and varying adoption.

---

## Edge Cases

1. **Single-field positional record `(int,)`** — should pass; a single-element record has no ambiguity to resolve via naming (there's nothing to distinguish it from), so flagging would be noise.
2. **Record destructured via a pattern (`final (name, age) = entry;`)** — should still flag the record type/access, but pass on the destructuring pattern itself, since pattern-matching already assigns local, meaningful names at the destructuring site (`name`, `age`), achieving the same readability goal without needing named fields.
3. **Record returned from a third-party/SDK API that only exposes positional fields** — should pass; the type is not under the project's control, so flagging the declaration is inapplicable — only flag record TYPES declared within the project.
4. **Record with a mix of positional and named fields (`(String, {int age})`)** — should flag the positional portion; the named portion is fine as-is.

---

## Alternatives Considered

- **Only flag the field-access sites (`.$1`), not the type declarations** — rejected; catching the declaration earlier prevents the unreadable access pattern from ever being written, rather than only catching it after the fact at every call site.

---

## Decision

---

## Implementation Notes

---

## Commits

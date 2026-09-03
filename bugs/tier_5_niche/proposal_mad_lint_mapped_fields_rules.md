# PROPOSAL: MadBrains `mappedFields` Convention Rule Family (4 Rules)

**Status: Open**

Created: 2026-09-02
Type: New rule (family)
Related rules: `json_parser_requirements`

---

## Summary

Add a package-specific rule family enforcing the MadBrains-internal `mappedFields` convention, ported from `mad_lint` (pub.dev). The convention is a lightweight, non-codegen alternative to `json_serializable`: a class exposes a `mappedFields` getter returning a `Map<String, dynamic>` (or similar) that pairs field names to value-producing expressions, used by the team's internal (de)serialization/diffing tooling. This proposal covers all 4 `mappedFields`-specific rules as one family since they share one detection target (the `mappedFields` getter) and one internal-convention audience.

**Closes gap:** `mad_lint` (pub.dev) — `mapped_fields_key_value_mismatch`, `mapped_fields_must_be_expression`, `mapped_fields_must_return_map`, `missing_mapped_fields_getter`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`mappedFields` is a convention, not a language feature — nothing stops a class from getting the shape wrong (missing the getter entirely, returning the wrong type, using a key that doesn't match the field it maps, or building the map with a statement instead of a pure expression). Because the convention underpins the team's internal tooling (likely serialization/diffing/form-binding), a malformed `mappedFields` getter fails silently at the tooling layer rather than at compile time — exactly the gap a lint rule closes.

- **`missing_mapped_fields_getter`** — a class opted into the convention (e.g. via a marker interface/annotation/mixin) but never defines `mappedFields`.
- **`mapped_fields_must_return_map`** — the getter's declared or inferred return type isn't `Map<String, dynamic>` (or the project's expected map shape).
- **`mapped_fields_must_be_expression`** — the getter body is a block (`{ ... }`) doing imperative construction instead of a single expression (`=> {...}`), making the mapping harder to statically verify and diff against fields.
- **`mapped_fields_key_value_mismatch`** — a map entry's string key doesn't match the name of the field its value expression reads (e.g. `'name': age`), a copy-paste bug in exactly the kind of hand-written mapping this convention exists to make explicit.

---

## Detection / Behavior

Only active when the class implements/mixes the project's `mappedFields`-convention marker (an interface, mixin, or annotation identified during implementation), matching how saropa gates other project-local conventions.

### Should flag (bad code)

```dart
// missing_mapped_fields_getter
class UserRecord implements MappedFieldsContract { // LINT — implements the contract but no mappedFields getter defined
  final String name;
  final int age;
}

// mapped_fields_must_return_map
class UserRecord implements MappedFieldsContract {
  final String name;
  List<String> get mappedFields => [name]; // LINT — must return Map<String, dynamic>
}

// mapped_fields_must_be_expression
class UserRecord implements MappedFieldsContract {
  final String name;
  @override
  Map<String, dynamic> get mappedFields { // LINT — block body; use an expression body
    final map = <String, dynamic>{};
    map['name'] = name;
    return map;
  }
}

// mapped_fields_key_value_mismatch
class UserRecord implements MappedFieldsContract {
  final String name;
  final int age;
  @override
  Map<String, dynamic> get mappedFields => {'name': age}; // LINT — key 'name' maps to field `age`
}
```

### Should pass (good code)

```dart
class UserRecord implements MappedFieldsContract {
  final String name;
  final int age;

  @override
  Map<String, dynamic> get mappedFields => {'name': name, 'age': age}; // OK — expression body, correct type, matching keys
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Package-specific to a MadBrains-internal convention with no upstream package on pub.dev to gate against; opt-in for teams that adopt the convention.

---

## Edge Cases

1. **Project without the `mappedFields` marker interface/annotation at all** — all 4 rules are inert.
2. **`mappedFields` key matching a renamed/aliased field via `@MappedKey('alias')`-style annotation (if the convention supports renaming)** — `mapped_fields_key_value_mismatch` should read the alias, not the field's Dart identifier, when present.
3. **Computed/derived value not directly reading a same-named field (e.g. `'fullName': '$first $last'`)** — should pass; the mismatch check only applies when the value expression is a bare identifier reference to a differently-named field, not to composite expressions.
4. **Getter delegates to a private helper method returning the map** — `mapped_fields_must_be_expression` should still require the getter itself to be `=> helper()`, not flag the helper's own body.

---

## Alternatives Considered

- **4 separate proposal files** — rejected per project convention for the mad_lint batch (see task instructions); the rules share one detection target and one internal-convention audience.

---

## Decision

---

## Implementation Notes

- Rule ids: `mapped_fields_key_value_mismatch`, `mapped_fields_must_be_expression`, `mapped_fields_must_return_map`, `missing_mapped_fields_getter`.
- Requires confirming with MadBrains/internal source how the `mappedFields` contract is actually marked (interface vs. mixin vs. annotation) before implementation — the marker mechanism is inferred here, not confirmed.

---

## Commits

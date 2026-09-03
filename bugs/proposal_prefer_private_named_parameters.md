# PROPOSAL: Prefer Named Parameters for Private-Field-Only Initializers

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_named_parameters` (general positional-vs-named heuristic — this proposal targets a narrower, specific Dart 3.12 shorthand case), `prefer_required_before_optional`/`prefer_grouped_by_purpose` (sibling parameter-shape rules in `lib/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart`)

---

## Summary

Add a rule that flags a **public, positional** constructor parameter whose sole purpose is initializing a **private** field (`this._field`), since Dart 3.12+ offers a shorthand where the parameter itself can be declared private and named, better signaling that the parameter is implementation detail rather than public API surface.

**Closes gap:** DCM `prefer-private-named-parameters` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`plans/GAP_ANALYSIS.md` Gap Theme 11 ("New Dart 3.12/3.13 language-feature rules") specifically calls this out: "many_lints covers newer Dart syntax saropa doesn't yet: ... `prefer_private_named_parameters` (public named parameter that only initializes a private field → Dart 3.12 shorthand)." A public-looking parameter name (`Foo({required this.name})`) that maps to a private field (`this._name`) creates a signature that reads as public API when the underlying storage is explicitly marked internal-only — callers see `name:` in autocomplete and documentation with no indication that the corresponding state is private and unstable. Marking the parameter itself as conceptually private-only (and named, since a private positional-only parameter loses the self-documenting call-site clarity that named parameters provide) closes that signal gap and is directly analogous to saropa's own note in Gap Theme 11 that saropa already covers the sibling dot-shorthand rules for constructors/enums/static fields — this is "a narrow follow-up, not a new category," per that same gap-analysis note.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Cache {
  final Map<String, int> _entries;

  Cache(this._entries);  // LINT — positional param initializing a private field
}
```

### Should pass (good code)

```dart
class Cache {
  final Map<String, int> _entries;

  Cache({required this._entries});  // OK — named, signals internal-only intent at the call site
}

// Also OK: parameter initializes a PUBLIC field — this rule only targets
// private-field-only initializers, not general positional-vs-named style
// (that broader case is prefer_named_parameters' territory).
class User {
  final String name;

  User(this.name);  // OK — public field, out of scope for this rule
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: this is a narrow, opinionated signal-quality convention about API surface communication rather than a correctness or even a general readability concern — it only fires on the specific intersection of "positional" + "initializes a private field," a combination most teams will encounter rarely per class. Pedantic (the strictest, most niche tier) is the appropriate home, consistent with how saropa scopes Dart-3.x-shorthand-adjacent style rules; Comprehensive would overstate its universality since it doesn't address a broad class of bugs the way the Comprehensive-tier `avoid_banned_*` config rules address team governance.

---

## Edge Cases

1. **Multiple positional parameters where only one initializes a private field** — the rule should report only on the specific parameter initializing the private field, not the whole parameter list, so `Cache(this.label, this._entries)` (public `label`, private `_entries`) flags only the second parameter.
2. **Optional positional parameters (`[this._entries]`)** — still positional, still applicable; the rule's applicability is about positional-vs-named, not required-vs-optional, so `Cache([this._entries])` should flag the same as a required positional parameter.
3. **Already-named parameters that are positional-style but wrapped for other reasons** — a parameter already declared as named (`{this._entries}` or `{required this._entries}`) should NOT flag; the rule's entire purpose is nudging positional-only private-field initializers toward the named form, so a parameter that's already named has nothing to correct here regardless of whether the field itself is private.

---

## Alternatives Considered

- **Broadening `prefer_named_parameters` to also cover this case** — rejected; that rule's existing scope (per `plans/GAP_ANALYSIS.md`'s own note under solid_lints' `number_of_parameters`) targets excess positional-parameter counts generally, a different signal (too many positional params) from this proposal's specific signal (private-field-only initializer should be named regardless of how many total parameters exist). Conflating the two would make `prefer_named_parameters`'s diagnostic message less precise for both cases.
- **Flagging ANY private field with a positional initializing formal regardless of naming, without requiring the "named" correction** — rejected because the value of this rule specifically comes from steering toward Dart 3.12's private-named-parameter shorthand as the fix, matching DCM's exact framing; a bare "don't use positional for private fields" rule without the named-parameter destination would be a less actionable, less specific version of the same idea.

---

## Decision

---

## Implementation Notes

Register via `context.addConstructorDeclaration`, walk `node.parameters.parameters`, filter to `FieldFormalParameter` nodes where `param.isPositional` (or `!param.isNamed`) and the resolved field's `.name.startsWith('_')` (via `param.name?.lexeme` prefix check, or resolving `param.element` to confirm the underlying `FieldElement.isPrivate`, consistent with how `AvoidReferencingDiscardedVariablesRule` in `code_quality_avoid_rules.dart` already resolves elements before matching underscore-prefixed names).

---

## Commits

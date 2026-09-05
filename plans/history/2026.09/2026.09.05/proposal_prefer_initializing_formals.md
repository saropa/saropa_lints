# PROPOSAL: Prefer Initializing Formals Over Constructor Body Assignment

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_constructor_body_assignment` (`lib/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart:820`, `PreferConstructorBodyAssignmentRule`) — **this proposal is the direct opposite recommendation and MUST be mutually exclusive with it; see the dedicated section below.**

---

## Summary

Add an opt-in stylistic rule that flags constructor parameters manually assigned to a matching field in the constructor body or initializer list (`Foo(String name) : this.name = name;` or `Foo(String name) { this.name = name; }`) when the parameter could instead use Dart's `this.field` initializing-formal shorthand.

**Closes gap:** DCM `prefer-initializing-formals` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## CRITICAL: Direct Conflict With `prefer_constructor_body_assignment`

**saropa_lints already ships the exact opposite rule.** `PreferConstructorBodyAssignmentRule` (`lib/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart:820`, rule id `prefer_constructor_body_assignment`) flags the `this.field` shorthand and recommends explicit body/initializer-list assignment instead — its own doc comment states: "Constructor uses this.field shorthand which prevents adding validation or transformation logic. Use an explicit initializer list or body assignment instead to keep the constructor flexible."

This proposal (`prefer_initializing_formals`) recommends the literal opposite: use `this.field` shorthand instead of explicit assignment. **These two rules must never both be enabled in the same project** — doing so would make every constructor either report `prefer_constructor_body_assignment` (if it uses the shorthand) or `prefer_initializing_formals` (if it doesn't), with no way to satisfy both simultaneously. This is not a bug to fix; it is an inherent, permanent property of two genuinely opposite style preferences, exactly like the existing `prefer_blank_line_after_declarations`/`prefer_compact_declarations` pair or `prefer_blank_lines_between_members`/`prefer_compact_class_members` pair already shipped as intentionally-opposite sibling rules in `stylistic_whitespace_constructor_rules.dart`.

**Implementation requirement:** both rules must be documented (in each rule's DartDoc and in `ROADMAP.md`) as an explicit "pick one" pair, following the same "This is an **opinionated rule** - not included in any tier by default" framing already used throughout `stylistic_whitespace_constructor_rules.dart` for its other opposite-pairs (`PreferNoBlankLineBeforeReturnRule` vs. the default-tier `NewlineBeforeReturnRule`, `PreferCompactDeclarationsRule` vs. `PreferBlankLineAfterDeclarationsRule`, `PreferConstructorAssertionRule` vs. `PreferFactoryForValidationRule`). Neither rule should ever appear in the same tier preset or rule pack as the other; both are opt-in-only. A future validator/config-lint should ideally warn if a project's `analysis_options_custom.yaml` enables both `prefer_constructor_body_assignment` and `prefer_initializing_formals` simultaneously, though implementing that guard is optional scope for this proposal — the documentation requirement above is the hard minimum.

---

## Motivation

DCM (dcm.dev) ships `prefer-initializing-formals`, which is the mainstream, Effective-Dart-aligned preference: use `this.field` shorthand to avoid the boilerplate and repetition of manually writing `Foo(String name) : this.name = name;` when there is no validation or transformation happening. saropa_lints already models this exact opinionated-pair pattern for several other constructor conventions in the same file (see `PreferConstructorAssertionRule` vs. `PreferFactoryForValidationRule`, both opt-in and mutually exclusive by design) — this proposal fills the missing "prefer the shorthand" half of the assignment-style pair, giving teams that want the DCM-aligned default a way to enforce it, while `prefer_constructor_body_assignment` remains available for teams that deliberately want explicit assignment everywhere (e.g. to leave room for future validation logic without a later refactor).

---

## Detection / Behavior

### Should flag (bad code)

```dart
class User {
  final String name;
  final int age;

  User(String name, int age)
      : this.name = name,  // LINT — could use this.name shorthand
        this.age = age;    // LINT — could use this.age shorthand
}
```

### Should pass (good code)

```dart
class User {
  final String name;
  final int age;

  User(this.name, this.age);  // OK — uses initializing-formal shorthand
}

// Also OK: assignment involves transformation/validation, so the shorthand
// genuinely cannot express it — same exemption PreferConstructorBodyAssignmentRule
// implicitly assumes when it argues FOR keeping body assignment "to allow
// validation or transformation logic."
class Email {
  final String value;

  Email(String raw) : value = raw.trim().toLowerCase();  // OK — transformation present
}
```

---

## Proposed Tier

Tier: Comprehensive (opt-in, never bundled into a default tier preset)
Justification: matches the tier placement of its direct sibling `prefer_constructor_body_assignment`, which is explicitly "**not included in any tier by default**" per its own doc comment. Since the two rules are mutually exclusive by design (see above), neither can be a default-tier rule — doing so would force every project using the default tiers into an unresolvable conflict the moment they also opt into the other. Comprehensive keeps it available but never auto-enabled.

---

## Edge Cases

1. **Assignment with transformation/validation (`value = raw.trim()`)** — must NOT flag; this is the case where the shorthand genuinely cannot apply (the RHS is not a bare parameter reference), and it is the documented reason `prefer_constructor_body_assignment` exists — the two rules should agree on this exemption even while disagreeing on the "no transformation" case.
2. **Fields with a default value provided elsewhere (not the parameter itself)** — `Foo({int count = 0}) : this.count = count;` is a straightforward shorthand candidate (`Foo({this.count = 0});`) and should flag; the default-value redirection doesn't change the applicability of the shorthand.
3. **`final` vs. mutable fields, and `super.field` forwarding** — `this.field` initializing formals work for both `final` and non-`final` instance fields; the rule should not special-case field mutability. A parameter forwarded straight to `super(...)` (already covered by the separate `prefer_super_parameters` rule) is a distinct shape and should not double-report here — restrict detection to same-class field assignments only.

---

## Alternatives Considered

- **Modifying `prefer_constructor_body_assignment` in place to flip its default recommendation** — rejected outright; that would silently change behavior for every existing user of that rule and destroy the "team picks their preferred convention" flexibility the opposite-pair pattern is designed to preserve. A new, separate rule id is the only safe way to add DCM's opposite recommendation.
- **A single configurable rule with a `preference: shorthand | explicit` config flag instead of two separate rule ids** — rejected for consistency with the project's existing convention of shipping opposite-pairs as fully separate rule classes/ids (`PreferBlankLineAfterDeclarationsRule`/`PreferCompactDeclarationsRule`, `PreferBlankLinesBetweenMembersRule`/`PreferCompactClassMembersRule`) rather than a single parameterized rule — this keeps each rule's `// ignore:` suppression, tier membership, and diagnostic message independently manageable.

---

## Decision

---

## Implementation Notes

---

## Commits

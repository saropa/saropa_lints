# PROPOSAL: Flag Classes Eligible for Dart 3.13 Primary Constructor Syntax

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_private_named_parameters`, `prefer_returning_shorthands`

---

## Summary

Add `prefer_primary_constructors` to flag a class whose entire constructor is a trivial "assign every parameter to a matching final field" pattern (the classic value-object/DTO shape), recommending Dart 3.13's primary-constructor syntax (`class Point(this.x, this.y);`) instead of the field declarations plus explicit constructor body.

**Closes gap:** many_lints `prefer_primary_constructors` (Gap Theme 11 — new Dart 3.12/3.13 language-feature rules). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 11.

---

## Motivation

Primary constructors are Dart 3.13's answer to the boilerplate of declaring `final` fields and then a same-shaped constructor purely to initialize them — a pattern that appears constantly in DTOs, value objects, and simple data classes. Once a project's minimum SDK constraint supports 3.13, flagging the old two-part spelling nudges the codebase toward the more concise, less error-prone (no risk of a field/parameter mismatch) syntax.

---

## Detection / Behavior

Flag a class declaration whose field list and single unnamed constructor are fully expressible as a primary constructor: every constructor parameter is `this.fieldName`, there is no constructor body beyond an optional `super(...)` call or assertion, and the class has no other constructors.

### Should flag (bad code)

```dart
class Point {
  final double x;
  final double y;

  Point(this.x, this.y); // LINT — eligible for Dart 3.13 primary constructor syntax
}
```

### Should pass (good code)

```dart
class Point(this.x, this.y) {
  // OK — primary constructor
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: requires a Dart 3.13+ SDK constraint to be applicable, and is a language-modernization style rule rather than a bug-catcher — placed at Comprehensive to avoid firing on projects with an older SDK floor. The rule should also self-gate on the project's declared SDK constraint (`environment.sdk` in `pubspec.yaml`) and stay silent below 3.13, regardless of tier.

---

## Edge Cases

1. **Constructor with a non-trivial body (validation, derived-field assignment)** — should NOT flag; primary constructors only support the pure "assign all parameters to fields" shape, so any additional logic disqualifies the class.
2. **Class with multiple constructors (named + unnamed)** — should NOT flag; Dart's primary-constructor syntax replaces the *default* constructor only, and a class needing additional named constructors cannot fully migrate.
3. **Class with mutable (non-`final`) fields** — should NOT flag; primary constructors in Dart 3.13 require the corresponding fields be `final` (or otherwise compatible with the shorthand); a mutable field breaks the eligible shape.
4. **Project's `pubspec.yaml` SDK constraint floor below 3.13** — should NOT flag at all, since the syntax wouldn't compile; this is a hard gate, not merely a tier suggestion.
5. **Class already `extends`/`implements`/`with` another type with its own constructor requirements** — should still flag if the primary-constructor syntax supports forwarding via `super(...)`/initializer list equivalents; needs discussion for the exact `super`-call compatibility boundary.

---

## Alternatives Considered

- **Auto-fix that rewrites the class declaration** — defer to a follow-up; the rewrite touches the class signature, every field declaration, and the constructor simultaneously, which is a larger structural edit worth validating carefully before shipping as an automatic fix.

---

## Decision

---

## Implementation Notes

---

## Commits

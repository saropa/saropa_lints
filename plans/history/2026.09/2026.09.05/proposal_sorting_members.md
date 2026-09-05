# PROPOSAL: Enforce Annotation-Opt-In Member Ordering Per Class

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_member_ordering` (existing saropa rule — a blanket, always-on rule requiring fields/constructors/methods ordering across the whole codebase. This proposal is an annotation-opt-in EXTENSION of the same underlying concept: instead of one fixed rule applied everywhere, a class explicitly opts in via an annotation to declare its own desired member order, giving teams granular per-class control rather than an all-or-nothing blanket policy.)

---

## Summary

Add `sorting_members` to check member declaration order ONLY on classes carrying a project-defined ordering annotation (e.g. `@SortMembers` or similar), flagging any annotated class whose actual member order (fields, constructors, getters/setters, methods, overrides, and/or alphabetical-within-category) doesn't match the declared policy. Unlike saropa's existing `prefer_member_ordering`, which applies a fixed 3-bucket order everywhere, this rule is opt-in per class — a team can enforce strict ordering on its most-churned/most-reviewed classes without forcing the same policy onto every class in the codebase.

**Closes gap:** essential_lints `sorting_members` (github.com/FMorschel/essential_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Saropa's `prefer_member_ordering` already enforces a fixed field-then-constructor-then-method order across the whole codebase — useful as a broad style baseline, but inflexible: some teams want STRICTER ordering (alphabetical-within-category, explicit getter/setter/override grouping) on a subset of classes that see heavy review traffic or many contributors, without imposing that stricter bar everywhere. Conversely, some classes (generated-adjacent hand-written boilerplate, DSL-builder classes with an intentionally unconventional layout) legitimately want to be EXEMPT from ordering enforcement entirely. A blanket rule can't express either of these without a growing exception list; an annotation-opt-in rule expresses both naturally: annotate the classes that should be checked, leave everything else alone.

This mirrors a pattern already familiar from other opt-in analysis annotations (`@immutable`, `@sealed`) — a class marks itself as participating in a stricter contract, and tooling enforces that contract only where asked. essential_lints ships `sorting_members` as exactly this: a project-defined annotation drives per-class ordering enforcement, giving teams granular control that a single project-wide rule cannot.

---

## Detection / Behavior

Flag a class declaration carrying the project-configured ordering annotation (default marker name `@SortMembers`, configurable) whose actual member declaration order does not match the configured category order (default: fields, constructors, getters/setters, methods, overrides) and/or alphabetical-within-category ordering when that option is enabled.

Un-annotated classes are never inspected — this rule is opt-in only, distinct from `prefer_member_ordering`'s blanket enforcement.

### Should flag (bad code)

```dart
@SortMembers()
class UserProfile { // LINT — a method is declared before the fields/constructor
  void refresh() {
    // ...
  }

  UserProfile({required this.name, required this.email});

  final String name;
  final String email;
}
```

### Should pass (good code)

```dart
@SortMembers()
class UserProfile { // OK — fields, then constructor, then methods, in order
  UserProfile({required this.name, required this.email});

  final String name;
  final String email;

  void refresh() {
    // ...
  }
}
```

```dart
// OK — no @SortMembers annotation, so member order is never checked
// regardless of layout (still subject to prefer_member_ordering if enabled
// project-wide, but exempt from THIS rule specifically).
class ScratchBuilder {
  void step3() {}
  void step1() {}
  void step2() {}
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Annotation-opt-in style enforcement is a deliberate, granular-control feature for teams already invested in strict code organization — not a universal correctness concern. Comprehensive matches saropa's placement for other opt-in, annotation-gated style rules; teams that want it enable it per-class, and it does nothing in projects that never apply the annotation.

---

## Edge Cases

1. **Class with no `@SortMembers` annotation** — must never flag; opt-in only, this is the core distinction from `prefer_member_ordering`.
2. **Annotation with configurable category order** (`@SortMembers(order: [MemberCategory.constructors, MemberCategory.fields, MemberCategory.methods])`) — the rule should read the configured order from the annotation arguments rather than assuming a fixed default, to genuinely give teams control rather than just a differently-fixed order.
3. **Alphabetical-within-category option** (`@SortMembers(alphabetical: true)`) — when enabled, should additionally flag two same-category members declared out of alphabetical order, on top of the category-order check.
4. **Static members mixed with instance members** — the default category buckets should treat static fields/methods as their own sub-category (matching common convention: statics first within each bucket) unless the annotation configuration says otherwise; document the default explicitly since this is a common source of disagreement.
5. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies, and generated files would never carry the annotation regardless.
6. **`@SortMembers` on an abstract class / mixin** — should apply the same check; ordering enforcement is equally meaningful for abstract member declarations.

---

## Alternatives Considered

- **Extend `prefer_member_ordering` itself with an opt-out annotation instead of building a separate opt-in rule** — rejected; inverting the default (blanket-on, opt-out per class) is a different design with different migration cost for existing codebases already relying on `prefer_member_ordering`'s current blanket behavior. A separate opt-in rule keeps the existing rule's behavior unchanged while adding the granular-control capability essential_lints demonstrates, without a breaking behavior change to `prefer_member_ordering`.
- **Reuse `prefer_member_ordering`'s exact fixed 3-bucket order with no per-class configuration** — rejected; the value proposition of an opt-in annotation is largely lost if it can't also let teams customize the order/strictness per class. Configurable category order and alphabetical-within-category are the features that make this a genuine gap-closer rather than a cosmetic duplicate of the existing rule.

---

## Decision

---

## Implementation Notes

---

## Commits

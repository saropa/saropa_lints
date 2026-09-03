# PROPOSAL: `avoid_widget_operator_equals` — Flag `operator ==` Overridden on a Widget Subclass

**Status: Declined**

Created: 2026-09-02
Type: New rule
Related rules: `require_extend_equatable` (direct philosophical conflict — see Decision)

---

## Summary

`flutter_best_practices_lints`' `avoid_widget_operator_equals` would flag a Flutter `Widget` subclass that overrides `operator ==` (and correspondingly `hashCode`) directly, on the position that Widgets are meant to be treated as cheap, ephemeral, identity-based descriptions of UI state — overriding equality on them is framed as an anti-pattern that can cause subtle correctness and performance issues (e.g. interfering with `const` widget canonicalization assumptions, or making `didUpdateWidget`/`shouldRebuild` comparisons behave unexpectedly when equality no longer reflects identity).

**Closes gap:** `flutter_best_practices_lints` `avoid_widget_operator_equals` (github.com/AndrewDongminYoo/custom_linters, packages/flutter_best_practices_lints). This is a documented philosophical conflict, not a build target — see `plans/GAP_ANALYSIS.md` "flutter_best_practices_lints" Gaps section, which already flags this exact conflict.

---

## Motivation

The case for the rule, as flutter_best_practices_lints frames it: Flutter's `Widget.canUpdate` and the framework's diffing machinery are built around widgets being compared primarily by `runtimeType` and `key`, with `const` widget instances relying on constructor-argument-based canonicalization at compile time rather than a custom runtime `==`. A hand-rolled `operator ==` on a Widget can silently change how the framework treats "is this the same widget" in ways that are easy to get subtly wrong, and rarely buys anything a `key` doesn't already provide for the cases Widgets are actually compared in (list diffing, `GlobalKey` state preservation).

**This directly conflicts with an existing saropa_lints rule and is declined for that reason — see Decision.**

---

## Detection / Behavior — what the rule WOULD do

### Would flag (if implemented)

```dart
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  Widget build(BuildContext context) => Text(name);

  @override
  bool operator ==(Object other) => // LINT (per flutter_best_practices_lints)
      other is UserCard && other.userId == userId && other.name == name;

  @override
  int get hashCode => Object.hash(userId, name);
}
```

### Would pass (if implemented)

```dart
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  Widget build(BuildContext context) => Text(name);
  // OK — no custom equality; relies on identity / const canonicalization / key.
}
```

---

## Proposed Tier

Tier: N/A — declined before tier assignment.

---

## Edge Cases

Not evaluated in depth — the proposal is declined before implementation-level design.

---

## Alternatives Considered

- **Implement as a narrow, opt-in stylistic rule** disabled by default so it does not fight `require_extend_equatable` in typical configurations — rejected; even opt-in, the rule would actively contradict saropa's own default-path guidance the moment a user enables both, and saropa's tier system does not have a mechanism to say "these two rules disagree, pick one" beyond leaving both off by default, which defeats the purpose of shipping either.
- **Carve out a Widget-specific exception inside `require_extend_equatable`** (stop flagging `operator ==` overrides specifically on Widget subclasses) instead of adding a new opposing rule — this is the live alternative if saropa ever wants to adopt the flutter_best_practices_lints position; it would mean `require_extend_equatable` goes silent on Widgets rather than shipping a second rule that actively contradicts it. Not proposed for adoption here — see Decision.

---

## Decision

**Declined.** This rule is the direct inverse of saropa's existing `require_extend_equatable` (`ExtendEquatableRule`, `lib/src/rules/packages/equatable_rules.dart:73`). `require_extend_equatable` fires on **any** class — Widget or not — that overrides `operator ==` without extending `Equatable`/mixing in `EquatableMixin`, and its correction message actively recommends extending `Equatable` for "cleaner equality implementation." It has no Widget-subclass exception today; a `StatelessWidget`/`StatefulWidget` that overrides `==` without `Equatable` is flagged exactly the same as any other class.

Implementing `avoid_widget_operator_equals` as specified would mean saropa ships two rules that, applied to the same `Widget` overriding `operator ==`, give a developer opposite instructions in the same pass: `require_extend_equatable` says "extend Equatable to get consistent equality here," while `avoid_widget_operator_equals` says "do not have custom equality on this Widget at all." A user with both enabled gets simultaneous, contradictory diagnostics on the same line — not a matter of tuning tiers or severities, since the two rules disagree on the *goal*, not just the *style*.

`plans/GAP_ANALYSIS.md` already classifies this as a documented philosophical conflict rather than a gap to close, alongside the sibling conflict `prefer_widget_class_over_widget_helper` (flutter_best_practices_lints wants private `_build*` methods; saropa's `prefer_widget_methods_over_classes` recommends the opposite). Per [`feedback_understand_before_questioning_architecture.md`], `require_extend_equatable`'s Equatable-everywhere position is saropa's established, deliberate stance — this proposal does not attempt to relitigate that choice, it documents why `avoid_widget_operator_equals` cannot be added alongside it without producing contradictory rule output. Revisiting this would require first deciding whether saropa wants a Widget-specific carve-out in `require_extend_equatable` (see Alternatives Considered), which is a separate, deliberate design decision, not a byproduct of this proposal.

---

## Implementation Notes

None — declined.

---

## Commits

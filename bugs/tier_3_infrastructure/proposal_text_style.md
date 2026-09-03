# PROPOSAL: Trace `TextStyle` Literals Back to a `@designSystem`-Annotated Typography Source

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: avoid_hardcoded_text_styles (false cognate — see Motivation), radius/edge_insets/box_shadow/theme_data/box_constraints (sibling design-system-provenance proposals in the same family — none of these files need to exist yet for this proposal)

---

## Summary

Add `text_style` to flag a literal `TextStyle(...)` constructor call used directly in widget code that is NOT a reference back to a member of a project's `@designSystem`-annotated typography-token source class (e.g. `AppTypography.heading1`). Scoped to `TextStyle` only — the sibling token types (`Radius`, `EdgeInsets`, `BoxShadow`, `ThemeData`, `BoxConstraints`) are separate proposals in the same family, not covered here.

**Closes gap:** design_system_lints (github.com/pattobrien/design_system_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Gap Theme 8: Design-system token provenance".

---

## Motivation

`design_system_lints`' core mechanism is generic and repo-wide: a project marks a single source-of-truth class with `@designSystem`, and every literal of a matching type anywhere in the codebase is flagged unless it can be traced back to a member reference on that annotated class. This is a fundamentally different check from value-shape heuristics — it doesn't care whether a `TextStyle` "looks hardcoded" by some fixed rule (specific fields set, magic numbers present); it cares whether the value traces back to the ONE authorized source, full stop.

**False-cognate warning:** saropa already has a similarly-named rule, `avoid_hardcoded_text_styles`. Verified via `Grep` on `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (class `AvoidHardcodedTextStylesRule`, code `avoid_hardcoded_text_styles`): that rule's actual detection logic flags an inline `TextStyle(...)` used directly in a `Text`/`RichText`/`DefaultTextStyle` widget's `style:` argument ONLY when the `TextStyle` sets a literal numeric `fontSize` or `fontWeight` value — its problem message reads "Inline TextStyle with hardcoded fontSize, fontWeight, and color values creates scattered styling that drifts from the design system over time," and its correction message points to `Theme.of(context).textTheme`. So the existing rule is NOT about missing `onHover`/interaction-state handlers (that description does not match the verified source) — it is a narrower, heuristic hardcoded-literal check scoped to `fontSize`/`fontWeight` inside a specific widget-nesting shape (`TextStyle` passed straight into `Text`/`RichText`/`DefaultTextStyle`'s `style:` argument), and it does not check color, does not fire on a `TextStyle` assigned to a variable/field/constant, and has no concept of an `@designSystem`-annotated provenance source at all. This proposal (`text_style`) is broader and structurally different in mechanism: type-driven, annotation-provenance-based, catching ANY `TextStyle(...)` literal anywhere in the codebase (not just the one specific inline-in-`Text`-widget shape) that isn't traceable to the designated source class. The two rules are complementary, not duplicates — implementing this proposal does not make `avoid_hardcoded_text_styles` redundant, and vice versa.

---

## Detection / Behavior

Given a project class annotated `@designSystem` whose static members/getters return `TextStyle` values (the project's canonical typography tokens), flag any `TextStyle(...)` `InstanceCreationExpression` anywhere in widget code that is not itself a member of the `@designSystem`-annotated class's own declaration and is not a direct reference to (or `.copyWith()` call on) one of that class's `TextStyle`-typed members.

### Should flag (bad code)

```dart
// app_typography.dart
@designSystem
class AppTypography {
  static const TextStyle heading1 = TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
}

// some_screen.dart
Widget build(BuildContext context) {
  return Text(
    'Welcome',
    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    // LINT — text_style: this TextStyle literal is not a reference to
    // AppTypography (the project's @designSystem source); even though the
    // values happen to match AppTypography.heading1, duplicating them here
    // means the two will drift the next time one is edited.
  );
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  return Text(
    'Welcome',
    style: AppTypography.heading1, // OK — direct reference to the design-system source
  );
}

Widget buildEmphasized(BuildContext context) {
  return Text(
    'Welcome',
    style: AppTypography.heading1.copyWith(color: Colors.red), // OK — .copyWith() on the source
  );
}
```

---

## Proposed Tier

Tier: Comprehensive/Pedantic, opt-in — the rule is inert on any project that has not declared an `@designSystem`-annotated typography class, so it produces zero diagnostics by default; matches saropa's placement for other annotation-gated, project-configuration-dependent rules.

---

## Edge Cases

1. **`TextStyle` literal inside the `@designSystem`-annotated class's own declaration** — must pass; the source-of-truth class is where the literals are SUPPOSED to live. Only usages elsewhere are in scope.
2. **`.copyWith()` chains on a traced reference** — should pass, per the Detection section; a `.copyWith()` off an already-traced token is the sanctioned way to derive variants, not a fresh untraced literal.
3. **`const TextStyle(...)` used for a genuinely one-off, non-design-system style (e.g. a debug overlay, a third-party widget's required literal argument)** — real false-positive risk; consider an escape hatch (`// ignore: text_style` with the standard verified-false-positive justification, or a config allowlist of file globs exempt from the check) since not every `TextStyle` in a large app is a design-system violation.
4. **No `@designSystem`-annotated class present in the project at all** — should produce zero diagnostics; the rule has nothing to trace against and must not fall back to some other heuristic (that would just re-implement `avoid_hardcoded_text_styles` under a different name).
5. **Multiple classes annotated `@designSystem`** (e.g. one for typography, one for spacing) — the rule must resolve which annotated class's members are `TextStyle`-typed and trace only against those, ignoring annotated classes whose members are a different type (radius, spacing, etc.) — relevant once the sibling `radius`/`edge_insets`/etc. proposals are also implemented and share the same `@designSystem` annotation mechanism.

---

## Alternatives Considered

- **Extend `avoid_hardcoded_text_styles` in place to add provenance tracing** — rejected; that rule's existing detection (inline literal-in-widget-argument, fontSize/fontWeight-only heuristic) is a fundamentally different mechanism from annotation-driven provenance tracing (any-location, type-driven, source-of-truth-aware). Bolting provenance tracing onto it would conflate two independently useful but mechanically distinct checks under one rule, and would require every `avoid_hardcoded_text_styles`-only project (no `@designSystem` class) to somehow opt out of the new behavior. A separate rule keeps both independently selectable.

---

## Decision

---

## Implementation Notes

---

## Commits

# PROPOSAL: Flag Hardcoded `EdgeInsets` Arguments Outside the Design System

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_hardcoded_colors`, `no_magic_number` (same "trace to design-system source" family, different value type)

---

## Summary

Add `edge_insets` to flag `EdgeInsets.all(...)`, `EdgeInsets.symmetric(...)`, `EdgeInsets.only(...)`, and `EdgeInsets.fromLTRB(...)` constructed with a raw numeric literal instead of a named design-system spacing token.

**Closes gap:** `design_system_lints` `edge_insets`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "design system" gaps section, alongside sibling gaps `box_shadow`, `radius`, `theme_data`, `box_constraints` covering the same "trace hardcoded value to annotated design-system source" engine.

---

## Motivation

Saropa already flags hardcoded colors and magic numbers, but spacing values (`EdgeInsets`) are just as prone to inconsistent one-off literals (`EdgeInsets.all(16)` scattered everywhere instead of `EdgeInsets.all(Spacing.md)`), which is exactly the class of drift a design-system enforcement engine exists to prevent. This closes a real gap: saropa has no general "trace hardcoded value to annotated design-system source" engine yet, only per-value-type heuristics against `Theme.of(context)`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Padding(
  padding: EdgeInsets.all(16), // LINT — hardcoded EdgeInsets value; use a design-system spacing token
  child: Text('Hello'),
);
```

### Should pass (good code)

```dart
Padding(
  padding: EdgeInsets.all(Spacing.md), // OK — references a design-system token
  child: Text('Hello'),
);
```

---

## Proposed Tier

Tier: Comprehensive
Justification: design-system consistency rule; valuable but requires project-specific configuration (recognizing the project's spacing token source), so placed alongside other opt-in design-system-family rules rather than Essential/Recommended.

---

## Edge Cases

1. **`EdgeInsets.zero`** — should pass; zero is a semantic constant, not a magic literal.
2. **`EdgeInsets.all(0)`** — should pass for the same reason as `EdgeInsets.zero`; treat `0` as always allowed.
3. **Value that is a local `const` computed from a token (`const _padding = Spacing.md * 2;`)** — should pass; the numeric literal traces back to a token even if not inline.
4. **Test/fixture files constructing arbitrary `EdgeInsets` for golden tests** — should pass; standard test-file suppression applies.

---

## Alternatives Considered

- **Ship as a strict "must equal a value in the configured token list" check** — deferred; requires a design-system-token registry mechanism shared with `box_shadow`/`radius`/`theme_data`/`box_constraints`. Build the shared registry first, then implement all five sibling rules against it rather than duplicating detection logic five times.

---

## Decision

---

## Implementation Notes

Should share a common "design-system token source" configuration/detection mechanism with the sibling gaps (`box_shadow`, `radius`, `theme_data`, `box_constraints`) rather than being built in isolation — check whether any of those already has a proposal or partial implementation before starting.

---

## Commits

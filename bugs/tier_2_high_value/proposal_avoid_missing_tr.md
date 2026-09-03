# PROPOSAL: Flag User-Facing String Literals Not Passed Through `easy_localization`'s `.tr()`

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `easy_localization` package)
Related rules: `avoid-missing-tr-on-strings` (companion, narrower variant covering only bare string-literal
arguments — see `bugs/tier_2_high_value/proposal_avoid_missing_tr_on_strings.md`)

---

## Summary

Add `avoid-missing-tr` (saropa id: `avoid_missing_tr`) to flag a string literal used as visible UI text
(passed to `Text(...)`, an `AppBar` `title:`, a button `label:`, etc.) that is not wrapped with
`easy_localization`'s `.tr()` extension (or `tr(...)` function form). saropa's existing translation-hygiene
rules are keyed to its own `l10n()` convention and do not recognize `easy_localization`'s `.tr()` API at all.

**Closes gap:** `dart_code_metrics_presets` `avoid-missing-tr` (easy_localization preset). Implementing this
proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Uncovered ecosystem
packages" section.

---

## Motivation

saropa already enforces "externalize every user-facing string" for its own `l10n()` convention (see
`.claude/rules/i18n.md` for saropa's own dogfood policy), but a project using `easy_localization` instead of
saropa's `l10n()` helper gets zero coverage today — a hardcoded English string in a `Text()` widget passes
silently. This is the same defect class saropa treats as critical in its own codebase, just unrecognized for
a different (very widely used) localization package.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Text('Welcome back') // LINT — avoid_missing_tr: user-facing string literal not localized via .tr()
```

### Should pass (good code)

```dart
Text('welcome_back'.tr()) // OK — routed through easy_localization
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `easy_localization` dependency note)
Justification: Only fires in projects depending on `easy_localization`; localization-completeness concern,
matching the tier saropa would assign an equivalent rule for its own `l10n()` convention if extended to a
second i18n package.

---

## Edge Cases

1. **Non-user-facing strings**: `Key('...')`, route names, asset paths, `debugPrint`/`log` arguments, CSS-
   like identifiers — should pass; scope detection to the same widget-property allowlist saropa already uses
   for its own translation-readiness rule (`Text` content, `label:`, `title:`, `tooltip:`, `hintText:`, etc.).
2. **A string built from `.tr()` plus concatenation** (`'prefix'.tr() + suffix`) — should pass for the
   `.tr()`-wrapped portion; a separate concatenation-vs-interpolation rule already covers word-order concerns.
3. **Empty string or purely symbolic literal** (`''`, `'-'`, `'%'`) — should pass; matches saropa's own
   symbols/glyphs exemption in `.claude/rules/i18n.md`.
4. **Project does not depend on `easy_localization`** — must not fire; gate on package presence like
   saropa's other ecosystem-specific rules.

---

## Alternatives Considered

- **Merge with `avoid-missing-tr-on-strings`** into one rule — rejected; the source packages ship them as two
  distinct codes with different scopes (general UI-property strings vs. bare string-literal arguments to any
  function), so keep them as separate saropa rules to match the granularity of the prior art and allow
  independent tier/severity tuning.

---

## Decision

---

## Implementation Notes

---

## Commits

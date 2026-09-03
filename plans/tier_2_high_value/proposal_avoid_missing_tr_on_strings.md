# PROPOSAL: Flag Bare String-Literal Arguments Not Passed Through `easy_localization`'s `.tr()`

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `easy_localization` package)
Related rules: `avoid-missing-tr` (companion, broader variant covering user-facing widget properties — see
`plans/tier_2_high_value/proposal_avoid_missing_tr.md`)

---

## Summary

Add `avoid-missing-tr-on-strings` (saropa id: `avoid_missing_tr_on_strings`) to flag a bare string-literal
argument passed directly to a function/constructor parameter where a `.tr()`-wrapped (translation-key)
string is expected — a narrower, call-site-argument-focused variant of `avoid-missing-tr` that checks
function arguments generally rather than only known Flutter widget UI properties.

**Closes gap:** `dart_code_metrics_presets` `avoid-missing-tr-on-strings` (easy_localization preset).
Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`
"Uncovered ecosystem packages" section.

---

## Motivation

Companion gap to `avoid-missing-tr`: user-facing strings reach the UI not just through recognized Flutter
widget properties (`Text`, `label:`, `title:`) but also through custom app-level functions that take a
message/label string parameter (`showSnackBar(message: 'Saved!')`, `AppDialog.show(title: 'Confirm')`).
`easy_localization`'s dedicated `avoid-missing-tr-on-strings` code targets exactly this broader
argument-position case, separately from the widget-property-scoped `avoid-missing-tr`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

showSnack(context, 'Saved successfully'); // LINT — avoid_missing_tr_on_strings: bare string literal argument, not .tr()-wrapped
```

### Should pass (good code)

```dart
showSnack(context, 'saved_successfully'.tr()); // OK — routed through easy_localization
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `easy_localization` dependency note)
Justification: Only fires in projects depending on `easy_localization`; same localization-completeness
concern as its companion `avoid-missing-tr`, at the same tier.

---

## Edge Cases

1. **Non-user-facing string arguments**: identifiers, format strings for `DateFormat`, regex patterns,
   `assert()` messages meant for developers — should pass; this is the highest false-positive-risk rule in
   this pair since it inspects generic function arguments rather than a known UI-property allowlist. Requires
   either an explicit parameter-name allowlist (`message`, `title`, `label`, `text`, `hint`) or an opt-in
   per-function annotation to keep noise manageable.
2. **A `.tr()`-wrapped argument already** — should pass.
3. **String argument to a logging/debug function** (`log('debug: $x')`) — should pass; not user-facing.
4. **Project does not depend on `easy_localization`** — must not fire; gate on package presence like
   saropa's other ecosystem-specific rules.

---

## Alternatives Considered

- **Ship only `avoid-missing-tr` and skip this narrower variant** — considered, since the false-positive risk
  here is materially higher (any string-typed parameter named suggestively could false-positive). Kept as a
  separate proposal so the parameter-name-allowlist design question is scoped and decided independently,
  rather than silently dropping a rule the source preset ships as distinct.

---

## Decision

---

## Implementation Notes

---

## Commits

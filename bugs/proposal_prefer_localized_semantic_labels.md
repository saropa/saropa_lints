# PROPOSAL: Flag Hardcoded English Strings Passed to Semantic/A11y Label Parameters

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_image_semantics` (requires a `semanticLabel` exist — this proposal requires that label, once present, be localized rather than a hardcoded literal), `require_autofill_hints` (`lib/src/rules/widget/forms_rules.dart:1751`, sibling a11y-parameter rule)

---

## Summary

Add a rule that flags a string literal passed directly to `Semantics(label: ...)`, `Semantics(hint: ...)`, `Semantics(value: ...)`, or the `semanticLabel`/`tooltip` parameters of built-in widgets (`Icon`, `Image`, `IconButton`), instead of a call through the project's `l10n()` localization function.

**Closes gap:** DCM `prefer-localized-semantic-labels` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`saropa_lints` already enforces that a11y-critical widgets carry a semantic label at all (`require_image_semantics`, `require_semantic_label_icons` at `lib/src/rules/ui/accessibility_rules.dart:3541`) and separately enforces that ordinary UI copy is externalized for translation (`.claude/rules/i18n.md`'s `l10n()` convention, enforced project-wide for the VS Code extension's own TypeScript surface). Neither existing rule checks that a *semantic* label specifically is localized: a developer can satisfy `require_image_semantics` by writing `semanticLabel: 'Profile photo'` — a hardcoded English literal — and no current rule flags it, so screen-reader users on non-English locales hear English announcements even in an otherwise fully localized app. This is a silent, easy-to-miss regression class because the visible on-screen text is correctly localized while the parallel a11y-only string is not, so it is invisible to a translator doing a visual QA pass — only a screen-reader audit catches it.

DCM (dcm.dev) ships `prefer-localized-semantic-labels` for this exact gap. `saropa_lints` has no equivalent — the existing a11y rules check presence of a label, never its localization status.

---

## Detection / Behavior

Flag any `StringLiteral` (including string interpolation with only literal segments) passed as the `label`, `hint`, or `value` named argument to a `Semantics(...)` constructor, or as `semanticLabel`/`tooltip` to `Icon`, `IconButton`, `Image`/`ImageIcon`, `FloatingActionButton`. Pass when the argument is a `MethodInvocation`/property access resolving to the project's localization delegate (matched the same way saropa's other i18n-adjacent checks resolve `AppLocalizations.of(context)!.xxx` / a project-configured `l10n()` wrapper — reuse the existing localization-call detector from `lib/src/rules/ui/internationalization_rules.dart` rather than re-implementing string-vs-l10n-call matching).

### Should flag (bad code)

```dart
Semantics(
  label: 'Delete conversation', // LINT — hardcoded, not localized
  child: IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
)

IconButton(
  icon: const Icon(Icons.close),
  tooltip: 'Close dialog', // LINT — hardcoded semantic tooltip
  onPressed: () => Navigator.pop(context),
)
```

### Should pass (good code)

```dart
Semantics(
  label: AppLocalizations.of(context)!.deleteConversationLabel, // OK — localized
  child: IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
)

IconButton(
  icon: const Icon(Icons.close),
  tooltip: AppLocalizations.of(context)!.closeDialogTooltip, // OK
  onPressed: () => Navigator.pop(context),
)
```

---

## Proposed Tier

Tier: Recommended
Justification: this is an accessibility correctness gap (WCAG 3.1.2 "Language of Parts" implications for assistive technology) layered on top of an internationalization requirement most production apps already hold themselves to for visible text — Recommended matches the tier of saropa's other a11y-label-presence rules (`require_image_semantics` ships in the default set) since the failure mode (English-only screen-reader announcements in a localized app) is a real accessibility regression, not a stylistic preference.

---

## Edge Cases

1. **Non-natural-language semantic values** (`Semantics(value: '${progress}%')` where the interpolated content is a raw number, not translatable prose) — should pass; the rule should require the literal to contain at least one alphabetic word run before flagging, avoiding false positives on purely numeric/symbolic semantic values.
2. **`Semantics.fromProperties` and custom `SemanticsProperties`-based widgets** — same detection should apply to the `label`/`hint`/`value` fields of a `SemanticsProperties(...)` literal, not just the `Semantics()` widget constructor shorthand.
3. **Debug-only or internal-tooling widgets** (a developer settings screen never shipped to end users) — out of scope for a first cut; the rule does not attempt to distinguish internal debug UI from user-facing UI, matching how saropa's other i18n rules currently behave (flag everywhere, rely on `// ignore:` for genuinely internal-only screens).
4. **Empty-string / decorative semantics** (`Semantics(label: '', excludeSemantics: true)`) — should pass; an empty literal is not English display text requiring translation.

---

## Alternatives Considered

- **Fold this into `require_image_semantics`/`require_semantic_label_icons` as an additional check rather than a new rule** — rejected because those rules target different widget types and the localization check is a distinct concern (presence vs. quality of the label) that applies uniformly across `Semantics`, `Icon`, `IconButton`, and `Image`; a single cross-cutting rule avoids duplicating the localization-call-detection logic four times.
- **Require type resolution to the specific project's localization class** — the existing `internationalization_rules.dart` detector already handles the common `AppLocalizations`/generated-l10n patterns without full type resolution; reusing it keeps this rule's `usesTypeResolution` cost low.

---

## Decision

---

## Implementation Notes

---

## Commits

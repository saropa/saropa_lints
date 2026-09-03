# PROPOSAL: Flag Progress Indicators Missing Semantic Labels

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_image_semantics` (`lib/src/rules/ui/accessibility_rules.dart:1512`, same "widget needs a semantic label" shape applied to a different widget class)

---

## Summary

Add a rule that flags `CircularProgressIndicator`/`LinearProgressIndicator` constructed with no `semanticsLabel` (and, for determinate progress, no `semanticsValue`), leaving screen-reader users with no announcement that a loading/progress operation is in flight or how far along it is.

**Closes gap:** DCM `provide-progress-indicator-semantics` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`CircularProgressIndicator`/`LinearProgressIndicator` are purely visual by default — a spinning circle or filling bar conveys nothing to a screen-reader user unless `semanticsLabel` (announced description, e.g. "Loading") and, for a determinate progress bar, `semanticsValue` (the current percentage) are supplied. Without them, a blind user on a loading screen gets silence with no indication the app is working versus frozen — a common source of "is this app broken?" support tickets from assistive-tech users and a WCAG 4.1.2 (Name, Role, Value) failure for any progress indicator that conveys state.

DCM (dcm.dev) ships `provide-progress-indicator-semantics` for this. `saropa_lints` has the same shape of rule for `Image` (`require_image_semantics`) but nothing for progress indicators — grep for `semanticsLabel` across `lib/src/rules/` returns no rule definitions.

---

## Detection / Behavior

Visit `InstanceCreationExpression` for `CircularProgressIndicator`/`LinearProgressIndicator`. Flag when no `semanticsLabel` named argument is present. When the indicator is determinate (a non-null `value:` argument supplied, i.e. not the indeterminate default), additionally flag when `semanticsValue` is also absent — an indeterminate spinner only needs a label ("Loading"), but a determinate bar showing real progress should announce the value too.

### Should flag (bad code)

```dart
const CircularProgressIndicator() // LINT — no semanticsLabel

LinearProgressIndicator(
  value: uploadProgress, // LINT — determinate but no semanticsLabel/semanticsValue
)
```

### Should pass (good code)

```dart
const CircularProgressIndicator(
  semanticsLabel: 'Loading', // OK
)

LinearProgressIndicator(
  value: uploadProgress,
  semanticsLabel: 'Upload progress', // OK
  semanticsValue: '${(uploadProgress * 100).round()}%', // OK — determinate value announced
)
```

---

## Proposed Tier

Tier: Recommended
Justification: matches `require_image_semantics`'s tier — a widget-presence-of-semantic-parameter check with a trivial one-line fix and a real accessibility impact (WCAG 4.1.2) for any user relying on a screen reader during a loading state, which is a state every app has.

---

## Edge Cases

1. **Purely decorative/skeleton-loading shimmer indicators** (a custom shimmer widget, not `CircularProgressIndicator`/`LinearProgressIndicator` themselves) — out of scope; the rule only visits the two Material progress-indicator constructors, not arbitrary custom loading widgets.
2. **Indeterminate `LinearProgressIndicator` with no `value:`** — only `semanticsLabel` is required, not `semanticsValue`, since there is no numeric value to announce; the rule must distinguish determinate (has `value:`) from indeterminate (`value: null` or omitted) before deciding whether to require `semanticsValue`.
3. **Progress indicator wrapped in an ancestor `Semantics(label: ...)`** — should pass; an ancestor `Semantics` wrapper providing the same announcement makes the widget-level `semanticsLabel` redundant, so the rule should walk a bounded ancestor chain (same approach as the `require_input_field_label` proposal) before flagging.
4. **`CupertinoActivityIndicator`** — out of scope for v1; it has no `semanticsLabel` parameter in the Cupertino API at all, so flagging it would require a different fix pattern (external `Semantics` wrap) than the Material indicators; document as a known scope limit, potential follow-up rule.

---

## Alternatives Considered

- **Fold into a generic "loading state" rule that also checks `FutureBuilder`/`AsyncSnapshot` loading branches for indicator presence** — rejected as scope creep; that is a materially different check (is a loading state handled at all) from this proposal (is the loading indicator itself accessible), and conflating them would make the rule harder to reason about and test.
- **Require `semanticsValue` even for indeterminate indicators** — rejected; there is no meaningful percentage to announce for an indeterminate spinner, so requiring it would force developers to fabricate a value or add a suppression, producing noise without benefit.

---

## Decision

---

## Implementation Notes

---

## Commits

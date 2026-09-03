# PROPOSAL: Flag Slider Widgets Missing a Semantic Formatter Callback

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_progress_indicator_semantics` (proposed alongside this rule — same "assistive tech needs the numeric meaning of a visual control" concern applied to `Slider` instead of a progress bar)

---

## Summary

Add a rule that flags `Slider`/`RangeSlider` widgets with no `semanticFormatterCallback` (or `semanticFormatterCallback`/`semanticFormatterCallback` on `RangeSlider`), leaving screen-reader users to hear only a raw fractional value (e.g. "0.7") instead of a meaningful announcement (e.g. "70 percent", "$14", "Medium").

**Closes gap:** DCM `provide-slider-semantic-formatter` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`Slider` announces its raw `value` to screen readers by default when no `semanticFormatterCallback` is supplied — for a slider whose domain is not literally "a number between 0 and 1" (a price range, a font-size picker, a difficulty level, a volume percentage), the raw value announcement is meaningless or actively confusing to a screen-reader user ("0.42" instead of "Medium difficulty" or "$42"). This is a WCAG 4.1.2 (Name, Role, Value) gap distinct from simply having *a* semantic announcement — the announcement must convey the actual meaning of the value in context, which `semanticFormatterCallback` exists specifically to provide.

DCM (dcm.dev) ships `provide-slider-semantic-formatter` for this. `saropa_lints` has no rule inspecting `Slider` construction at all — grep for `semanticFormatterCallback` across `lib/src/rules/` returns no rule definitions.

---

## Detection / Behavior

Visit `InstanceCreationExpression` for `Slider`/`RangeSlider`. Flag when no `semanticFormatterCallback` named argument is present, UNLESS the slider's `min`/`max` are literal `0.0`/`1.0` (or omitted, defaulting to the same range) AND no `divisions`/`label` argument is set — a bare 0–1 continuous slider with no displayed label is the one case where the raw fractional value is arguably self-describing and DCM's own rule treats as lower-priority; treat this narrow case as a pass to avoid flagging trivial demo/placeholder sliders, but flag every slider with a custom `min`/`max` range, `divisions`, or an on-screen `label` (since a `label` argument already proves the developer intends the value to be human-meaningful, and the semantic announcement should match).

### Should flag (bad code)

```dart
Slider(
  value: fontSize,
  min: 12,
  max: 32,
  label: '${fontSize.round()}pt', // has a visible label...
  onChanged: (v) => setState(() => fontSize = v), // LINT — no semanticFormatterCallback to match it
)
```

### Should pass (good code)

```dart
Slider(
  value: fontSize,
  min: 12,
  max: 32,
  label: '${fontSize.round()}pt',
  semanticFormatterCallback: (v) => '${v.round()} points', // OK
  onChanged: (v) => setState(() => fontSize = v),
)

// Bare 0-1 continuous slider, no displayed label — raw fraction is
// arguably self-describing; not flagged in v1.
Slider(
  value: opacity,
  onChanged: (v) => setState(() => opacity = v), // OK — trivial 0-1 case
)
```

---

## Proposed Tier

Tier: Recommended
Justification: matches the sibling `require_progress_indicator_semantics` proposal's tier — a concrete WCAG 4.1.2 gap on a widget that commonly carries a meaningful (non-0–1) domain, with a low-cost fix; scoped narrowly enough (skipping the trivial bare 0–1 case) to avoid noise on placeholder/demo code.

---

## Edge Cases

1. **`RangeSlider`** — same requirement, checked via `semanticFormatterCallback` on the `RangeSlider` constructor (a single formatter callback applied to both thumbs, per the Flutter API); both start and end values benefit equally from a formatted announcement.
2. **Slider with `divisions` but no visible `label`** — should still flag; `divisions` alone indicates a stepped, meaningfully-quantized value (e.g. a 1–5 star rating slider) even without an on-screen `label`, so the rule's "has divisions" condition is independent of the "has label" condition.
3. **Disabled sliders** (`onChanged: null`) — still flagged if otherwise meeting the criteria; a disabled slider is still exposed to assistive tech with its current value, and the same announcement-quality concern applies.
4. **Custom-themed slider wrapped in a project-level `AppSlider` widget** — out of scope for the AST-level rule unless the project's `AppSlider` itself forwards to `Slider(...)` in the same file; whole-widget-library resolution is not attempted, matching how other saropa widget-detection rules scope to direct Flutter framework constructors.

---

## Alternatives Considered

- **Flag every `Slider` unconditionally, including bare 0–1 sliders** — rejected as producing noise on legitimately self-describing opacity/volume-fraction sliders where a raw percentage-like value needs no further explanation; the narrower "has a meaningful range/label/divisions" trigger targets the cases where the announcement is actually likely to be wrong.
- **Only check `RangeSlider`, leaving `Slider` for a later iteration** — rejected; `Slider` is the far more common widget and the primary source of the DCM-documented gap, so shipping only the rarer `RangeSlider` case first would miss most real-world instances.

---

## Decision

---

## Implementation Notes

---

## Commits

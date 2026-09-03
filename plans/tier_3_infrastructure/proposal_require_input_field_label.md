# PROPOSAL: Flag TextField/TextFormField Missing a Label

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_autofill_hints` (`lib/src/rules/widget/forms_rules.dart:1751`, sibling form-field a11y/UX rule — this proposal covers the label parameter, that one covers autofill hints)

---

## Summary

Add a rule that flags `TextField`/`TextFormField` widgets with no `decoration: InputDecoration(labelText: ...)` (or `label:`/`hintText:` as a fallback) and no external `Semantics(label: ...)`/preceding visible `Text` label wrapper, leaving the field unidentified to sighted users on focus and to screen-reader users entirely.

**Closes gap:** DCM `provide-input-field-label` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

An unlabeled text field is both a usability defect (a user who taps into a field mid-form and loses context of what it asks for has no on-field reminder) and a WCAG 3.3.2 ("Labels or Instructions") / 4.1.2 ("Name, Role, Value") accessibility failure — a screen reader announces an unlabeled `TextField` as just "text field, edit box" with no indication of purpose, forcing a blind user to guess from surrounding context or abandon the form. This is one of the most common a11y defects flagged in manual accessibility audits of Flutter apps, and it is entirely preventable by convention: every `TextField` should carry a `labelText`/`label`, or explicit `Semantics`.

DCM (dcm.dev) ships `provide-input-field-label` for exactly this. `saropa_lints` has form-adjacent rules (`require_autofill_hints`) but nothing checking label presence — grep for `labelText` across `lib/src/rules/` returns no rule definitions.

---

## Detection / Behavior

Visit `InstanceCreationExpression` nodes for `TextField`/`TextFormField`. Flag when: (a) there is no `decoration:` argument at all, or (b) `decoration:` is present but the `InputDecoration(...)` argument list has neither `labelText`/`label` nor `hintText` set, and (c) no ancestor `Semantics(label: ...)` wraps the field (checked by walking a bounded number of parent nodes, matching the pattern saropa's other widget-context rules use for ancestor checks) and no `SizedBox`-adjacent sibling `Text` widget immediately precedes it in the same `Column`/`Row` (a common non-`InputDecoration` labeling pattern this rule should still accept).

### Should flag (bad code)

```dart
TextField(
  controller: _emailController, // LINT — no labelText, no decoration
)

TextFormField(
  controller: _nameController,
  decoration: const InputDecoration(), // LINT — decoration present but no label/hint
)
```

### Should pass (good code)

```dart
TextField(
  controller: _emailController,
  decoration: const InputDecoration(labelText: 'Email address'), // OK
)

TextFormField(
  controller: _nameController,
  decoration: const InputDecoration(hintText: 'Full name'), // OK — hintText accepted
)

Semantics(
  label: 'Search query',
  child: TextField(controller: _searchController), // OK — externally labeled
)
```

---

## Proposed Tier

Tier: Recommended
Justification: an unlabeled input field is a concrete, common accessibility and UX defect (WCAG 3.3.2/4.1.2) with a near-zero-cost fix (`labelText`) and essentially no legitimate exception in production forms — this matches the bar for saropa's other a11y-presence rules that ship in Recommended (`require_image_semantics`), rather than Essential (reserved for correctness/crash-class issues) or a lower tier where it would be easy to leave disabled.

---

## Edge Cases

1. **Search bars using `hintText` only, by design convention (no persistent `labelText`)** — should pass; `hintText` alone satisfies the check since it still gives assistive tech and users a description, matching the common Material search-field pattern.
2. **`TextField` inside a `Form` with a preceding non-`Semantics`, non-`InputDecoration` custom label widget** (e.g. a bespoke `FieldLabel(text: 'Email')` project widget immediately above it) — flagged by default since the rule cannot recognize arbitrary custom label widgets; document this as a known false-positive class resolvable via `// ignore:` with a one-line reason, or a follow-up config list of "known label widget names" if reports justify it.
3. **Obscured/password fields** (`obscureText: true`) — same requirement applies; a password field is exactly the kind of field where losing the on-field label after typing begins is most disorienting.
4. **`TextField` used purely as a disabled/read-only display element** (`enabled: false`, showing computed text) — still requires a label; a read-only field still needs identification of what value it is displaying.

---

## Alternatives Considered

- **Only check for `Semantics` wrapping, ignoring `InputDecoration.labelText`** — rejected; `labelText` is both the far more common pattern in Flutter forms and independently valuable for sighted users (visible floating label), not just assistive tech, so requiring the check to accept either is closer to real-world usage.
- **Also require a minimum label string length / non-generic text ("Enter text" style placeholders)** — deferred; that is a content-quality judgment better suited to manual review than an AST rule, and risks false positives on legitimately short labels ("Age", "ZIP").

---

## Decision

---

## Implementation Notes

---

## Commits

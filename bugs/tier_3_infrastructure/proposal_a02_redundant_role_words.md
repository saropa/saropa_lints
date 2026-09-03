# PROPOSAL: Flag Redundant Role Words in Semantic Labels ("button", "icon")

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_redundant_semantics_label` (if present, otherwise `none`)

---

## Summary

Add `avoid_redundant_label_role_words` to flag `Semantics(label: ...)` and similar accessibility-label strings that redundantly restate the control's own role — e.g. `label: 'Submit button'` on a widget the screen reader already announces as a button. Screen readers append the role automatically, so embedding it in the label produces double-announcement ("Submit button, button").

**Closes gap:** `flutter_a11y_lints` `A02` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Screen readers (TalkBack, VoiceOver) already announce a control's semantic role after its label. A label string that repeats the role word ("button", "icon", "image", "link") is a common, easy-to-miss authoring mistake that makes every activation of that control audibly redundant for blind and low-vision users. `flutter_a11y_lints` ships this as `A02`; it is cheap to detect via a string-content check and has an obvious, mechanical fix (strip the trailing/leading role word).

---

## Detection / Behavior

Flag string literal arguments to `label:` (in `Semantics(...)`, `ExcludeSemantics`, or the `semanticLabel:`/`tooltip:` parameters of core widgets) whose text ends or begins with a redundant role word ("button", "icon", "image", "link", "checkbox", "switch") that duplicates the role the widget itself already conveys (e.g. the label is on an `IconButton`, `ElevatedButton`, or a `Semantics(button: true)` ancestor).

### Should flag (bad code)

```dart
IconButton(
  icon: const Icon(Icons.send),
  tooltip: 'Send button', // LINT — "button" role is announced automatically
  onPressed: _send,
);
```

### Should pass (good code)

```dart
IconButton(
  icon: const Icon(Icons.send),
  tooltip: 'Send', // OK — role word omitted, screen reader appends "button" itself
  onPressed: _send,
);
```

---

## Proposed Tier

Tier: Recommended
Justification: Direct, easily-verified accessibility defect with a mechanical string fix; low false-positive risk once scoped to widgets with a known announced role.

---

## Edge Cases

1. **Role word inside a longer phrase not describing the control's own role** (e.g. "Icon of a running dog" as an image description) — needs discussion; should likely pass since "icon"/"image" there describes content, not role duplication of the wrapping widget.
2. **Custom widget with no detectable role** (plain `Container` wrapped in bare `Semantics(label: ...)`, no `button:`/`link:` flag set) — should pass; nothing to be redundant against.
3. **Localized strings via `l10n()`** — should flag on the literal English catalog value where inspectable; otherwise the rule can only catch inline literals directly in Dart source.
4. **Role word as part of a proper noun or brand string** ("Icon Studio") — needs discussion; risk of false positive, consider requiring the role word at the label's start/end only.

---

## Alternatives Considered

- **Regex-only scan without widget-role correlation** — rejected; too many false positives on labels that legitimately contain "button"/"icon" as content words rather than role duplication.

---

## Decision

---

## Implementation Notes

---

## Commits

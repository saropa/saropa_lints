# BUG: text-field form rules — fire on DropdownButtonFormField (not a text input)

**Status: Open**

Created: 2026-11-23
Rules: `require_autofill_hints`, `prefer_on_field_submitted`, `require_keyboard_action_type`, `require_text_input_type`, `prefer_text_input_action`, `avoid_uncontrolled_text_field`
File: `lib/src/rules/widget/forms_rules.dart` (lines ~1294, 1749, 1829, 1909, 1971); `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (~832)
Severity: False positive

---

## Summary

All six text-input rules report on `DropdownButtonFormField<String>(...)`. It is a `FormField` subclass but has no keyboard, no text, no controller, no submit action, and no autofill hints parameter, so none of the six requirements can be met.

---

## Attribution Evidence

```bash
grep -rn "'require_autofill_hints'" lib/src/rules/
# lib/src/rules/widget/forms_rules.dart:1749
grep -rn "'prefer_on_field_submitted'" lib/src/rules/
# lib/src/rules/widget/forms_rules.dart:1829
```

---

## Reproducer

```dart
DropdownButtonFormField<String>(
  value: selectedId,
  items: [for (final s in subjects) DropdownMenuItem(value: s.id, child: Text(s.label))],
  onChanged: (id) {}, // LINT x6 — but should NOT lint (no text input exists)
);
```

**Frequency:** Always (any `DropdownButtonFormField`)

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: widget has no `autofillHints`, `keyboardType`, `textInputAction`, `onFieldSubmitted` or `controller` parameters |
| **Actual** | Six diagnostics at the constructor call |

---

## Suggested Fix

Match the rules on `TextFormField` / `TextField` only, or skip any `FormField` subclass whose constructor lacks the parameter the rule asks for.

Related: a plain `TextField` holding free text (class short name, event title) has no matching autofill hint and no `onFieldSubmitted` (a `TextFormField` parameter). `require_autofill_hints` should not require a hint for non-identity free-text fields, and `prefer_on_field_submitted` should accept `onSubmitted` on `TextField`.

---

## Closed (2026-11-24)

Not reproducible by code reading. All six rules match by exact type name (TextField, TextFormField) and cannot fire on DropdownButtonFormField; prefer_on_field_submitted already accepts onSubmitted. No scan was run. The 'autofill hint for free-text fields' request is a heuristic change to require_autofill_hints, not a false positive; file separately if wanted.

# BUG: `require_text_overflow_handling` — Flags dynamic Text in slots that already wrap and bound width

**Status: Open**

Created: 2026-11-24
Rule: `require_text_overflow_handling`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~53)
Severity: False positive
Rule version: v3 | saropa_lints 17.7.9

---

## Summary

Any `Text(<non-literal>)` without `overflow` / `maxLines` / `softWrap` is reported, regardless of parent. In `ListTile` / `SwitchListTile` `title` and `subtitle`, the text wraps by default and the parent bounds its width, so horizontal overflow is not possible. Truncating there would hide copy users must read (large text sizes). The rule's own correction message says wrapping is preferred, yet it reports code that already wraps.

---

## Attribution Evidence

```bash
grep -rn "'require_text_overflow_handling'" lib/src/rules/
# lib/src/rules/widget/widget_patterns_require_rules.dart:53
```

---

## Reproducer

```dart
Widget toggle(String title, String subtitle) => SwitchListTile(
  title: Text(title),       // LINT — but should NOT lint: ListTile slot bounds width and wraps
  subtitle: Text(subtitle), // LINT — but should NOT lint
  value: true,
  onChanged: (_) {},
);
```

**Frequency:** Always for a non-literal first argument

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the Text is the `title`/`subtitle` argument of a ListTile-family widget, or a direct child of `Expanded`/`Flexible` |
| **Actual** | `[require_text_overflow_handling] Text displaying dynamic content (user input, API data, translations) without overflow handling can break layouts when the text is longer than expected. Unbounded text pushes sibling widgets off-screen, triggers RenderFlex overflow errors in Row/Column contexts, and creates inconsistent UI across locales with varying text lengths. {v3}` |

---

## Root Cause

The visitor inspects only the Text's own arguments and the first-argument expression type. It never checks the parent. The message describes `Row` overflow; `ListTile` slots cannot overflow horizontally.

## Suggested Fix

Skip when the Text is the `title`/`subtitle` argument of `ListTile`, `SwitchListTile`, `CheckboxListTile`, `RadioListTile`, `ExpansionTile`, or a direct child of `Expanded`/`Flexible`. Optionally report only when the ancestor chain reaches a `Row` without an `Expanded`/`Flexible` in between.

## Fixture Gap

1. `SwitchListTile(title: Text(variable))` — NO lint
2. `Row(children: [Text(variable)])` — LINT
3. `Row(children: [Expanded(child: Text(variable))])` — NO lint

---

## Environment

- saropa_lints version: 17.7.9
- Triggering project/file: jupiter-tablet `lib/ui/clarity_settings.dart` lines ~123-125 (SwitchListTile title/subtitle)

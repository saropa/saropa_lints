# BUG: `require_semantic_label_icons` — Flags decorative icons whose sibling label already names them

**Status: Open**

Created: 2026-11-24
Rule: `require_semantic_label_icons`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~3719)
Severity: False positive
Rule version: v2 | saropa_lints 17.7.9

---

## Summary

Every `Icon(...)` without `semanticLabel` is reported unless one of 5 ancestors is `ExcludeSemantics` or `Semantics(excludeSemantics: true)`. Icons inside a widget that already carries a text label (`ButtonSegment.label`, `FilledButton.icon` + `label`, `InputDecoration.labelText` + `prefixIcon`, a toast `title`) are decorative; Flutter guidance is to leave `semanticLabel` null so the label is not announced twice. The only ways to satisfy the rule are an `ExcludeSemantics` wrapper or an `// ignore:`. Expected: no report when the icon is the `icon:` / `prefixIcon:` / `suffixIcon:` / `leading:` argument of a widget or decoration that also supplies a text label.

---

## Attribution Evidence

```bash
grep -rn "'require_semantic_label_icons'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:3719
```

---

## Reproducer

```dart
SegmentedButton<int>(
  segments: const [
    // LINT — but should NOT lint: label 'Focus' already names the segment
    ButtonSegment(value: 0, label: Text('Focus'), icon: Icon(Icons.center_focus_strong)),
  ],
  selected: {0},
  onSelectionChanged: (_) {},
)

FilledButton.icon(
  onPressed: () {},
  icon: const Icon(Icons.arrow_forward), // LINT — but should NOT lint: label names the action
  label: const Text('Continue'),
)

const TextField(
  decoration: InputDecoration(
    labelText: 'School sign-in link',
    prefixIcon: Icon(Icons.link), // LINT — but should NOT lint: decorative, labelText names the field
  ),
)
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the icon is a decorative slot argument of a widget that also has a text label |
| **Actual** | `[require_semantic_label_icons] Icon child element is missing a semanticLabel, making it invisible or meaningless to screen readers and assistive technologies. All icons that convey information or actions in the widget tree must have a descriptive semanticLabel for accessibility compliance. {v2}` |

Adding `semanticLabel: 'Focus'` makes a screen reader announce "Focus, Focus".

---

## Root Cause

`runWithReporter` only checks (a) a `semanticLabel` argument and (b) `_hasSemanticExclusion` (ancestors within 5 levels: `ExcludeSemantics` / `Semantics(excludeSemantics: true)`). It never inspects the enclosing named argument (`icon:`, `prefixIcon:`) or sibling arguments (`label:`, `labelText:`, `title:`).

## Suggested Fix

In the `Icon` visitor, find the enclosing `NamedArgument` and its owning `InstanceCreationExpression`. Skip when the icon is passed via `icon` / `prefixIcon` / `suffixIcon` / `leading` and the owner has a sibling `label`, `labelText`, `title` or `child` argument that is a `Text`.

## Fixture Gap

1. `ButtonSegment(label: Text(..), icon: Icon(..))` — expect NO lint
2. `FilledButton.icon(icon: Icon(..), label: Text(..))` — expect NO lint
3. `InputDecoration(labelText: .., prefixIcon: Icon(..))` — expect NO lint
4. Standalone `Icon(Icons.add)` in a `Row` with no label — expect LINT

---

## Environment

- saropa_lints version: 17.7.9
- Triggering project/files: jupiter-tablet `lib/ui/clarity_settings.dart` (3 segments), `lib/ui/school_link_step.dart` (prefixIcon, button icon), `lib/ui/feedback.dart` (toast icon beside title)

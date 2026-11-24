# BUG: `prefer_skeleton_over_spinner` - Flags a CircularProgressIndicator used as a button's busy icon

**Status: Open**

Created: 2026-11-24
Rule: `prefer_skeleton_over_spinner`
File: `lib/src/rules/widget/ui_ux_rules.dart` (line ~893)
Severity: False positive
Rule version: {v?} | Since: unknown | Updated: unknown

---

## Summary

A 20x20 `CircularProgressIndicator` inside a button's `icon:` slot is the in-button busy cue for a one-shot action. A skeleton placeholder is for loading content layouts, not for button state; the rule has nothing to replace here.

---

## Attribution Evidence

```bash
grep -rn "'prefer_skeleton_over_spinner'" lib/src/rules/
# lib/src/rules/widget/ui_ux_rules.dart:893
```

---

## Reproducer

```dart
FilledButton.icon(
  onPressed: busy ? null : check,
  // LINT - but should NOT lint: spinner is the button's busy icon, not a content-loading placeholder.
  icon: busy
      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
      : const Icon(Icons.arrow_forward),
  label: const Text('Continue'),
)
```

**Frequency:** Always for this pattern.

## Expected

No diagnostic when the indicator is small, fixed-size, and inside a button (`icon:`/`child:` of a Button widget).

## Environment

saropa_lints 17.7.9; downstream app d:\src\jupiter-tablet, lib/ui/school_link_step.dart.

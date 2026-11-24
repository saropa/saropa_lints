# BUG: `require_disabled_state` - Flags a button whose onPressed is already null while busy

**Status: Open**

Created: 2026-11-24
Rule: `require_disabled_state`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~879)
Severity: False positive
Rule version: {v?} | Since: unknown | Updated: unknown

---

## Summary

`FilledButton.icon(onPressed: _busy ? null : _check, ...)` is the standard Flutter way to disable a button: a null `onPressed` makes Material render the disabled style. The rule still reports the button.

---

## Attribution Evidence

```bash
grep -rn "'require_disabled_state'" lib/src/rules/
# lib/src/rules/widget/widget_patterns_require_rules.dart:879
```

---

## Reproducer

```dart
// LINT on the next line - but should NOT lint: onPressed is null while _busy, so the button is disabled.
FilledButton.icon(
  onPressed: _busy ? null : _check,
  icon: const Icon(Icons.arrow_forward),
  label: const Text('Continue'),
)
```

**Frequency:** Always, for every button whose onPressed is a conditional that can be null.

## Expected

No diagnostic when `onPressed` is (or can be) null; that is the disabled state.

## Environment

saropa_lints 17.7.9; downstream app d:\src\jupiter-tablet, lib/ui/school_link_step.dart.

---

## Closed (2026-11-24)

By design. require_disabled_state intentionally flags a button whose onPressed is a conditional containing null and which has no style: argument; it asks for explicit disabled styling (disabledBackgroundColor / disabledForegroundColor). The reported code is the rules documented bad example (example/lib/widget_patterns/require_disabled_state_fixture.dart, expect_lint at line 113). Reporter guidance: add a style: with disabled colors, or use // ignore: require_disabled_state with a reason, or disable the rule for the project.

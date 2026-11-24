# BUG: `avoid_keyboard_overlap` — Flags a TextField that is built inside a scroll view owned by another file

**Status: Open**

Created: 2026-11-23
Rule: `avoid_keyboard_overlap`
File: `lib/src/rules/widget/forms_rules.dart` (line ~1521)
Severity: False positive
Rule version: unknown | saropa_lints 4.15.1 (downstream pubspec.lock)

---

## Summary

The rule looks for `viewInsets` handling or a scroll view around the TextField within the same file. In the downstream app, form widgets are built as plain `Column`s and mounted by a shared page frame (`SettingsPage` -> `CenteredScroll` -> `SingleChildScrollView`) in another file, under a `Scaffold` with the default `resizeToAvoidBottomInset: true`. The keyboard cannot cover the field; the rule cannot see the ancestor.

---

## Attribution Evidence

```bash
grep -rn "'avoid_keyboard_overlap'" lib/src/rules/
# lib/src/rules/widget/forms_rules.dart:1521
```

---

## Reproducer

```dart
// form.dart
class SignInForm extends StatelessWidget {
  const SignInForm({super.key});
  @override
  Widget build(BuildContext context) => Column(children: const [
        TextField(), // LINT, but should NOT lint: the only caller wraps this in a scroll view
      ]);
}
```

**Frequency:** Always for field-only widget files (5 sites in one sign-in form, 1 in a weather search row).

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the enclosing scroll view lives in a caller, or confidence too low to report |
| **Actual** | `[avoid_keyboard_overlap] TextField may be hidden behind the soft keyboard when no viewInsets handling is detected` |

## Suggested Fix

Do not report a TextField inside a widget that returns a bare `Column`/`Row` (no `Scaffold`, no route of its own); the decision belongs to the page that hosts it. Report only where a `Scaffold` body or a fixed-height container directly holds the field.

Observed in jupiter-tablet `lib/providers/jupiter/jupiter_login_form.dart` and `lib/ui/settings_pages.dart`.

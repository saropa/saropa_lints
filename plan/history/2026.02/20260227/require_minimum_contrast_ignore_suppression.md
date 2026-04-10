# Bug: require_minimum_contrast does not honor ignore comments

**Fixed (2026-02-27):** Rule now respects `// ignore:` and `// ignore_for_file:` via `IgnoreUtils.isIgnoredForFile` and `IgnoreUtils.hasIgnoreComment` in `lib/src/rules/accessibility_rules.dart`. Fixture and test added.

---

**Rule:** `require_minimum_contrast`  
**Severity:** Warning (as configured)  
**Status:** Fixed  
**Reported:** 2026-02-27  
**Fixed:** 2026-02-27

---

## Summary

The `require_minimum_contrast` rule reports low-contrast text in cases where the foreground/background pair is intentionally high contrast (e.g. white on black). Standard Dart/analyzer ignore comments (`// ignore: require_minimum_contrast` and `// ignore_for_file: require_minimum_contrast`) do not suppress the diagnostic, so consumers cannot document intentional exceptions (e.g. error placeholders, full-bleed overlays) without disabling the rule project-wide or living with a persistent warning.

---

## Resolution (2026-02-27)

The rule was not checking ignore directives. Fix applied:

- **File:** `lib/src/rules/accessibility_rules.dart`
- **Change:** Before reporting a violation, the rule now:
  1. Skips the file if `// ignore_for_file: require_minimum_contrast` (or hyphenated `require-minimum-contrast`) is present.
  2. Skips the specific occurrence if `// ignore: require_minimum_contrast` applies to the node (leading line, same line, or ancestor), using `IgnoreUtils.hasIgnoreComment` and `IgnoreUtils.isIgnoredForFile`.

Both underscore and hyphenated rule names in ignore comments are supported. A fixture case and test were added to guard against regression.

---

## References

- WCAG 2.1 Success Criterion 1.4.3 (Minimum Contrast): https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- Dart analyzer ignore comments: https://dart.dev/tools/diagnostic-messages#suppressing-diagnostics

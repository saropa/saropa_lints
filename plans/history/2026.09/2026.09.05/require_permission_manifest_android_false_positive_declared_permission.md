# BUG: `require_permission_manifest_android` — fires when permission IS declared in AndroidManifest.xml

**Status: Fixed**

<!-- Status values: Open -> Investigating -> Fix Ready -> Closed -->

Created: 2026-09-05
Rule: `require_permission_manifest_android`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~2511)
Severity: High (forces `// ignore:` workaround on common patterns)
Rule version: v2

---

## Summary

The rule fires on `import 'package:permission_handler/permission_handler.dart'` even when the corresponding Android permission IS declared in `android/app/src/main/AndroidManifest.xml`. The rule cannot read the manifest at analysis time, so it flags every permission_handler import unconditionally.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive -- rule IS defined here
grep -rn "'require_permission_manifest_android'" lib/src/rules/
# Result:
# lib/src/rules/widget/widget_patterns_require_rules.dart:2530:    'require_permission_manifest_android',
```

**Emitter registration:** `lib/src/rules/widget/widget_patterns_require_rules.dart:2530`
**Rule class:** `RequirePermissionManifestAndroidRule` -- registered at line 2511
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// File: lib/views/email/email_center_screen.dart
import 'package:permission_handler/permission_handler.dart'; // LINT -- but should NOT lint

// The CAMERA permission IS declared in android/app/src/main/AndroidManifest.xml line 40:
// <uses-permission android:name="android.permission.CAMERA" />
```

**Frequency:** Always -- fires on every permission_handler import regardless of manifest content.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic -- the permission is declared in AndroidManifest.xml |
| **Actual** | `[require_permission_manifest_android] Runtime permission request without corresponding manifest declaration` reported at line 14 |

---

## AST Context

```
CompilationUnit
  └─ ImportDirective ('package:permission_handler/permission_handler.dart')  <- node reported here
```

---

## Root Cause

The rule detects `permission_handler` imports and flags them with a reminder to declare the permission in AndroidManifest.xml. However, it operates purely at the Dart AST level and has no mechanism to read or parse the project's `android/app/src/main/AndroidManifest.xml` file. This means it fires unconditionally on every permission_handler import, even when the manifest already contains the correct `<uses-permission>` declaration.

The rule is structurally unable to verify its own premise -- it warns about a missing declaration it cannot check.

---

## Suggested Fix

Three options, in order of preference:

1. **Parse AndroidManifest.xml during analysis** -- resolve the project root from the analyzed file's path, read `android/app/src/main/AndroidManifest.xml`, and check for `<uses-permission>` elements. Skip the diagnostic if the relevant permission is declared. This may require `custom_lint`'s resolver to expose the project root.

2. **Configuration mechanism** -- allow projects to whitelist declared permissions in `analysis_options.yaml` under the `saropa_lints:` config block, e.g. `declared_permissions: [CAMERA, INTERNET, ...]`. Skip the diagnostic for whitelisted permissions.

3. **Downgrade to INFO severity** -- change the diagnostic severity to informational with a "verify manifest" message rather than a warning, so it serves as a reminder without forcing `// ignore:` workarounds.

---

## Fixture Gap

The fixture should include:

1. **permission_handler import with permission declared** -- expect NO lint (currently missing)
2. **permission_handler import without permission declared** -- expect LINT (likely exists)

---

## Environment

- saropa_lints version: current
- Triggering project/file: `d:\src\contacts\lib\views\email\email_center_screen.dart:14`

---

## Finish Report (2026-09-05)

Option 3 from Suggested Fix was applied: the rule's structural inability to read `AndroidManifest.xml`
at analysis time (options 1 and 2 both require reading project files the rule has no access to) means
it can never assert a permission is missing with confidence, so its severity was downgraded from
WARNING/`LintImpact.error` to INFO/`LintImpact.info`, and its message was reworded from an assertion
("Runtime permission request without manifest entry always fails") to an instruction to verify
("Verify that the required Android permission is declared in AndroidManifest.xml").

Changes:
- `lib/src/rules/widget/widget_patterns_require_rules.dart` — `RequirePermissionManifestAndroidRule`:
  `_code.severity` changed from `DiagnosticSeverity.WARNING` to `DiagnosticSeverity.INFO`; `impact`
  changed from `LintImpact.error` to `LintImpact.info`; problem/correction message text reworded to
  advisory phrasing; comments added explaining the rule cannot read the manifest and why INFO is
  therefore the correct ceiling for its confidence.
- `test/rules/widget/widget_patterns_rules_test.dart` — added a regression test asserting the rule's
  `code.severity.name == 'INFO'` and `impact == LintImpact.info`, so a future edit cannot silently
  re-promote the rule to WARNING/error without a test failure.
- `CHANGELOG.md` — added a `## [16.0.0-beta.5] — Unreleased` section (none existed after the
  beta.4 release) with a Fixed entry describing the behavior change.

No manifest-parsing logic was added (options 1/2 from Suggested Fix remain open future work); the
rule still cannot detect whether a permission is truly missing, it now says so honestly instead of
asserting a fact it cannot verify.

Verification: `dart test test/rules/widget/widget_patterns_rules_test.dart` — 219/219 passed
(218 existing + 1 new regression test).

# BUG: `avoid_screenshot_sensitive` — flags widgets by class-name words alone, including list pickers and "connected services" screens

**Status: Fixed**

Created: 2026-11-24
Rule: `avoid_screenshot_sensitive`
File: `lib/src/rules/security/security_network_input_rules.dart` (line ~2157)
Severity: False positive
Rule version: v5 | Since: unknown | Updated: 17.7.0

---

## Summary

The rule reports any class whose lowercase name contains one of `auth`, `account`, `profile`, `settings`, `pin`, `verify`, `transfer`, `login`, and so on, plus `screen`, `page`, `view` or `widget`. It never looks at what the class shows. A country picker, an import-options list and a connected-services screen are reported although they hold no financial or authentication data. `pin` is a substring match, so it also matches inside words such as "mapping" and "shipping".

---

## Attribution Evidence

```bash
python scripts/checks/check_report_attribution.py avoid_screenshot_sensitive
# OK    avoid_screenshot_sensitive: defined at lib/src/rules/security/security_network_input_rules.dart:2157
```

---

## Reproducer

Downstream app (contacts) classes reported, none holding sensitive data:

```dart
class UserCountryPickerWidget extends StatelessWidget { ... }   // lists countries
class UserImportOptionsWidget extends StatelessWidget { ... }   // list of import choices
class ConnectedServicesScreen extends StatelessWidget { ... }   // lists connected service names
```

The exact name word that matched each class was not captured; the full list of the 7 reported classes is: ConnectedServicesScreen, ConnectedServiceDetailScreen, UserLinkedContactWidget, UserCountryPickerWidget, UserContactOptionsView, UserImportOptionsWidget, `_SignInAuditPanel`.

The app already blocks screenshots app-wide through a user-controlled switch in `MainActivity.kt` (`setAppSwitcherPrivacy`), so per-class `FLAG_SECURE` code is not the right fix and the substring checks (`FLAG_SECURE`, `WindowManager`, `screenshot`) never see it because it lives in native code.

**Frequency:** Always for any matching class name.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Report only classes that render credentials, payment data or one-time codes, or let the host app declare protection through a configurable marker (annotation, project setting, or a recognised app-wide protection call). |
| **Actual** | `[avoid_screenshot_sensitive]` on 10 classes in one app, 7 distinct classes, all non-sensitive UI. |

---

## Root Cause

`runWithReporter` builds `isSensitive` purely from the lowercase class name against `_sensitiveScreenNames` (lines ~2165-2205) and then looks only for the strings `FLAG_SECURE`, `WindowManager`, `secureFlag`, `screenshot`, `Screenshot` inside the class source. Neither step uses the widget tree, the fields shown, or app-level protection.

Suggested fixes, in order of preference:
1. Require a sensitive signal in the class body (a `TextField` with `obscureText: true`, a payment or one-time-code field type, an autofill hint of `password` or `oneTimeCode`) in addition to the name.
2. Treat a project-level setting (analysis option) that declares app-wide screenshot protection as satisfying the rule.
3. Match whole words in the class name, not substrings, so `pin` no longer matches "mapping".

---

## Downstream impact

contacts app: 10 findings, 7 classes. The only available code fix is renaming the classes to avoid the words, which this project will not do for a name-matching heuristic.

## Finish Report (2026-11-24)

### Root cause

`runWithReporter` matched each entry of `_sensitiveScreenNames` as a substring of the lowercased class name, so `pin` matched inside `mapping` and `shipping`.

### Fix

Changes are in `lib/src/rules/security/security_network_input_rules.dart` (rule version v5 to v6).

- New static `AvoidScreenshotSensitiveRule.isSensitiveClassName` splits the class name into camelCase and acronym words. It requires a whole-word sensitive term plus a UI container word (screen, page, view, widget). A single trailing "s" is stripped for plurals, and adjacent word pairs are checked for terms such as SignIn and CreditCard.
- A cheap pre-check skips class names that contain no UI container word.
- The `_debugToolingNames` filter changed from substring to whole-word matching, so `ReviewerPaymentScreen` is no longer suppressed by `viewer`.
- Added inflections `authenticate`, `authentication`, `authenticator`, `authorization`, `verification` and `passcode`. These are new detections: `AuthenticationScreen`, `VerificationScreen`, `PasscodeScreen` and similar were not reported before. `pin` stays exact-match.

### Tests

- Positive and negative class-name lists in `test/rules/security/security_rules_test.dart`.
- Near-miss cases in `example/lib/security/avoid_screenshot_sensitive_fixture.dart`.

### Verification

182 passed, 0 failed across `security_rules_test`, `false_positive_fixes_test`, `saropa_lints_test`, `fixture_lint_integration_test` and `anti_pattern_detection_test`.

### Not done

- Scan CLI run against real code: unverified.
- Body-signal option (for example `obscureText`).
- Project-level protection setting.
- The seven class names in the original report contain no sensitive term even as a substring, so the reporting project may be running an older rule version. Re-check after release.

### Hardening (2026-11-24)

- Plural stripping never strips `ss` endings, and a stripped form matches only if it is itself in `_sensitiveScreenNames`; negative tests cover `AccessScreen`, `ProcessPage`, `ClassListView`, `StatusScreen`, `NewsWidget`. `SettingsScreen` remains positive.
- Classes whose final word is `state`, `model`, `viewmodel`, `controller`, `bloc`, `cubit`, `notifier` or `provider` are no longer treated as screens.
- A StatefulWidget is no longer reported when its paired `State<Widget>` class in the same file contains screenshot protection (`FLAG_SECURE`, `WindowManager` and the other markers). New `shouldReportClass` helper is covered by parsed-source tests for both the protected and unprotected case.
- Limitation documented in code: all-lowercase class names (`loginpage`) form one word and are not matched.
- Verification: 184 passed, 0 failed across the same five test files.

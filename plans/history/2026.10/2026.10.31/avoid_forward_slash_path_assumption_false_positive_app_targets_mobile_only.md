# BUG: `avoid_forward_slash_path_assumption` — Flags `'$dir/$name'` path building in an app that ships on iOS and Android only

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_forward_slash_path_assumption`
File: `lib/src/rules/platforms/windows_rules.dart` (line ~302)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags `'$dir/$name'` path building in an app that ships on iOS and Android only. In a downstream app review, 12 of 12 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_forward_slash_path_assumption'" lib/src/rules/
# lib/src/rules/platforms/windows_rules.dart:302:    'avoid_forward_slash_path_assumption',
```

**Emitter registration:** `lib/src/rules/platforms/windows_rules.dart:302`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
final Directory dir = Directory('$cachedContainerPath/$imageSubdirectory'); // LINT — but should NOT lint
final String targetPath = '${externalStoragePath.path}/$baseNameWithExtension'; // LINT — but should NOT lint
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/device_home_screen_widget/device_home_screen_widget_path_utils.dart:71,94,115; lib/utils/file_io/file_io.dart:271; lib/utils/avatar/avatar_image_utils.dart:98; lib/utils/language/pronunciation/name_pronunciation_ja_pack_service.dart:102,154,155,160. The app has no windows/ or linux/ platform folder; only ios/ and android/.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_forward_slash_path_assumption]` reported at each site above |

---

## Root Cause

The rule is a Windows rule and is applied regardless of the project's platforms. Forward slash is the correct separator on iOS and Android.

---

## Suggested Fix

Do not run the rule unless the project has a `windows/` runner folder (or pubspec declares the Windows platform). Alternatively place it in a Windows-only tier that a mobile app does not enable.

---

## Fixture Gap

The fixture for `avoid_forward_slash_path_assumption` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Resolution

Fixed. New `ProjectContext.isMobileOnlyApp` (Flutter app with `android/` and/or `ios/` and no web or desktop folder). `avoid_forward_slash_path_assumption` returns early for such projects, checked inside each callback so the standalone scan (which registers once and replays per file) honours it. Pure Dart packages and projects without a mobile-only layout still fire. Fixture has bad and good cases; verified with `dart run saropa_lints:scan` on scratch projects (pure Dart: 2 issues; Flutter with android/ios only: none).

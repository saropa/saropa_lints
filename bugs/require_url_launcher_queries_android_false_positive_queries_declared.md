# BUG: `require_url_launcher_queries_android` — fires when queries intent IS declared in AndroidManifest.xml

**Status: Open**

<!-- Status values: Open -> Investigating -> Fix Ready -> Closed -->

Created: 2026-09-05
Rule: `require_url_launcher_queries_android`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~2631)
Severity: High (forces `// ignore:` workaround on common patterns)
Rule version: v2

---

## Summary

The rule fires on `url_launcher` imports warning that `<queries>` blocks are missing from AndroidManifest.xml, but multiple `<queries>` blocks ARE declared in the manifest (lines 74-150, covering `http`, `https`, `mailto`, `tel`, and `sms` intents). The rule cannot read the manifest at analysis time.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive -- rule IS defined here
grep -rn "'require_url_launcher_queries_android'" lib/src/rules/
# Result:
# lib/src/rules/widget/widget_patterns_require_rules.dart:2650:    'require_url_launcher_queries_android',
```

**Emitter registration:** `lib/src/rules/widget/widget_patterns_require_rules.dart:2650`
**Rule class:** `RequireUrlLauncherQueriesAndroidRule` -- registered at line 2631
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// File: lib/views/system/news_screen.dart
import 'package:url_launcher/url_launcher.dart'; // LINT -- but should NOT lint

// The <queries> blocks ARE declared in android/app/src/main/AndroidManifest.xml lines 74-150:
// <queries>
//   <intent><action android:name="android.intent.action.VIEW" />
//     <data android:scheme="https" /></intent>
//   <intent><action android:name="android.intent.action.VIEW" />
//     <data android:scheme="http" /></intent>
//   <intent><action android:name="android.intent.action.VIEW" />
//     <data android:scheme="mailto" /></intent>
//   ...
// </queries>
```

**Frequency:** Always -- fires on every url_launcher import regardless of manifest content.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic -- `<queries>` blocks are declared in AndroidManifest.xml |
| **Actual** | `[require_url_launcher_queries_android] Without <queries> in manifest, url_launcher may silently fail on Android 11+` reported at line 49 |

---

## AST Context

```
CompilationUnit
  └─ ImportDirective ('package:url_launcher/url_launcher.dart')  <- node reported here
```

---

## Root Cause

Same structural limitation as `require_permission_manifest_android`. The rule detects `url_launcher` imports and flags them with a warning about missing `<queries>` blocks, but it operates purely at the Dart AST level with no mechanism to read or parse AndroidManifest.xml. It fires unconditionally on every url_launcher import.

---

## Suggested Fix

Same three options as `require_permission_manifest_android`:

1. **Parse AndroidManifest.xml** -- check for `<queries>` blocks with the relevant intent filters. Skip if present.

2. **Configuration mechanism** -- allow projects to declare `url_launcher_queries_configured: true` in `analysis_options.yaml` under `saropa_lints:`.

3. **Downgrade to INFO severity** -- informational reminder rather than a warning.

---

## Fixture Gap

The fixture should include:

1. **url_launcher import with queries declared** -- expect NO lint (currently missing)
2. **url_launcher import without queries declared** -- expect LINT (likely exists)

---

## Environment

- saropa_lints version: current
- Triggering project/file: `d:\src\contacts\lib\views\system\news_screen.dart:49`

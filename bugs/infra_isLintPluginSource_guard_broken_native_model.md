# BUG: Infrastructure — `isLintPluginSource` guard broken in native analyzer model

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-13
Rule: 43 guard sites across 12 rule files
File: `lib/src/native/saropa_context.dart` (line ~72) and all callsites
Severity: False positive (systemic)
Rule version: All rules using `context.isLintPluginSource` in `runWithReporter`

---

## Summary

The `isLintPluginSource` guard — used by 12 rule files (43 occurrences) to prevent rules from firing on their own source code — does not work in the native analyzer model. It runs once at rule registration time, not per-file. Result: rules fire on their own pattern-definition strings (OAuth URLs, sandbox URLs, crypto patterns, etc.), producing false positives.

Currently observed: 8 false positives from `avoid_ios_in_app_browser_for_auth` on lines 463-470 of `ios_platform_lifecycle_rules.dart`.

---

## Reproducer

The lint plugin analyzes its own `lib/src/rules/` files. `AvoidIosInAppBrowserForAuthRule` defines OAuth URL patterns as string constants:

```dart
static const List<String> _oauthPatterns = [
  'accounts.google.com/o/oauth',   // L463 — LINT (false positive)
  'appleid.apple.com/auth',        // L464 — LINT (false positive)
  'facebook.com/v',                // L465 — LINT (false positive)
  '/dialog/oauth',                 // L466 — LINT (false positive)
  'login.microsoftonline.com',     // L467 — LINT (false positive)
  'github.com/login/oauth',        // L468 — LINT (false positive)
  'twitter.com/oauth',             // L469 — LINT (false positive)
  'api.twitter.com/oauth',         // L470 — LINT (false positive)
];

static const Set<String> _webViewWidgets = {
  'WebView',        // L475 — triggers fileContent.contains('WebView') check
  'InAppWebView',
  'WebViewWidget',
};
```

The `addSimpleStringLiteral` callback finds OAuth patterns in lines 463-470, then checks if `fileContent` contains `'WebView'` — which it does (line 475). Both conditions pass, so all 8 strings are reported.

**Frequency:** Always — every time the analyzer processes `lib/src/rules/` files.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — these are pattern definitions inside the rule's own source, not user code |
| **Actual** | 8x `[avoid_ios_in_app_browser_for_auth] OAuth URL detected in WebView...` on lines 463-470 |

---

## Root Cause

### Architecture mismatch: old model vs native model

**Old model (custom_lint):** `run()` was called per-file. The `isLintPluginSource` guard ran per-file and correctly skipped the rule's own source.

**Native model (current):** `registerNodeProcessors()` is called **once per rule at startup**. It calls `runWithReporter()`, which registers AST callbacks via `context.addXxx()`. The `isLintPluginSource` check at the top of `runWithReporter()` runs once at registration time — it evaluates against whatever file happens to be current at registration, not against each analyzed file.

The per-file filtering system (`_wrapCallback` → `_shouldSkipCurrentFile` → `shouldSkipFile`) does NOT include `isLintPluginSource` in its checks. So the guard is dead code in the native model.

### Affected files (43 guard sites across 12 files)

| File | Count |
|------|-------|
| `config/dart_sdk_3_removal_rules.dart` | 16 |
| `config/migration_rules.dart` | 13 |
| `config/flutter_sdk_migration_rules.dart` | 4 |
| `config/sdk_migration_batch2_rules.dart` | 2 |
| `commerce/iap_rules.dart` | 1 |
| `config/config_rules.dart` | 1 |
| `config/dart_sdk_34_deprecation_rules.dart` | 1 |
| `network/api_network_rules.dart` | 1 |
| `packages/firebase_rules.dart` | 1 |
| `platforms/ios_platform_lifecycle_rules.dart` | 1 |
| `security/crypto_rules.dart` | 1 |
| `security/security_network_input_rules.dart` | 1 |

---

## Suggested Fix

### Option A: Framework-level fix (recommended)

Add lint plugin source detection to `_shouldSkipCurrentFile()` in `saropa_context.dart`. This fixes all 43 sites at once:

```dart
bool _shouldSkipCurrentFile() {
  final path = filePath;
  if (path.isEmpty) return false;
  if (path == _lastCheckedPath) return _wasLastFileSkipped;
  _lastCheckedPath = path;

  // Skip lint plugin source files — pattern definitions trigger self-referential FPs
  if (isLintPluginSource) return _wasLastFileSkipped = true;

  // ... rest of existing checks ...
}
```

After this, the per-rule `if (context.isLintPluginSource) return;` guards become redundant. All 43 guards were removed in Fix 2.

### Option B: Add to `_globalExcludedFolders`

Add `'/rules/'` and `'/fixes/'` to the `_globalExcludedFolders` set in `saropa_lint_rule.dart`. This is simpler but less precise — it would exclude ANY project's `/rules/` directory, not just the lint plugin's own.

**Recommendation: Option A.** It uses the existing `isLintPluginSource` property which is already designed for this exact purpose, and it's scoped correctly.

---

## Fixture Gap

No fixture is needed — this is infrastructure behavior. The fix should be verified by confirming the 8 false positives disappear after the change.

---

## Changes Made

- **`lib/src/native/saropa_context.dart`** (Fix 1): Added `isLintPluginSource` check at the top of `_shouldSkipCurrentFile()`, before any rule-specific filtering. This runs per-file (cached per path) and skips all files under `/rules/` or `/fixes/` directories. The check runs even when `_saropaRule` is null, so non-SaropaLintRule rules also skip plugin source.
- **12 rule files** (Fix 2): Removed all 43 dead `if (context.isLintPluginSource) return;` guards and their comments. These were no-ops in the native model. Files: `iap_rules.dart`, `config_rules.dart`, `dart_sdk_34_deprecation_rules.dart`, `dart_sdk_3_removal_rules.dart` (16), `flutter_sdk_migration_rules.dart` (4), `migration_rules.dart` (13), `sdk_migration_batch2_rules.dart` (2), `api_network_rules.dart`, `firebase_rules.dart`, `ios_platform_lifecycle_rules.dart`, `crypto_rules.dart`, `security_network_input_rules.dart`.
- **`CHANGELOG.md`**: Added entry under `[Unreleased] > Fixed`.

---

## Tests Added

- `dart test test/migration_rules_test.dart` — 95/95 pass (covers all migration rules affected by guard removal)
- `dart analyze --fatal-infos` — clean (confirms no syntax/import issues from removals)

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 10.11.1
- Dart SDK version: 3.11.4
- Triggering project/file: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` lines 463-470

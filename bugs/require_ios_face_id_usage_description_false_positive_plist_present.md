# BUG: `require_ios_face_id_usage_description` — False positive when `NSFaceIDUsageDescription` IS present in Info.plist

**Status: Open**

Created: 2026-05-04
Rule: `require_ios_face_id_usage_description`
File: `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart` (line ~676)
Severity: False positive
Rule version: v4 | Since: v2.4.0 | Updated: v4.13.0

---

## Summary

The rule fires on every `LocalAuthentication()` constructor and every `LocalAuthentication`-typed method call (`authenticate`, `canCheckBiometrics`, `getAvailableBiometrics`, `isDeviceSupported`) inside a project whose `ios/Runner/Info.plist` already contains a `<key>NSFaceIDUsageDescription</key>` entry. The rule has an `InfoPlistChecker` early-return guard that should skip exactly this case, but the guard is not catching the configured project — visitors register and the diagnostic fires four times in a single file.

---

## Attribution Evidence

```bash
# Positive — rule IS defined in saropa_lints
$ grep -rn "'require_ios_face_id_usage_description'" lib/src/rules/
lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:676:    'require_ios_face_id_usage_description',

# Negative — not in saropa_drift_advisor
$ grep -rn "'require_ios_face_id_usage_description'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
(0 matches)
```

**Emitter registration:** `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:676`
**Rule class:** `RequireIosFaceIdUsageDescriptionRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (severity 4)

---

## Reproducer

Project: `d:/src/contacts` (saropa_lints 13.4.1 from pub.dev, resolved from `^13.3.2`).

`ios/Runner/Info.plist` (line 89-90) contains:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Saropa uses Face ID to unlock contacts marked as biometrically protected.</string>
```

`lib/utils/user/security/biometrics.dart`:

```dart
import 'package:local_auth/local_auth.dart';

// LINE 13 — LINT (constructor) — but Info.plist HAS NSFaceIDUsageDescription, should NOT lint
final LocalAuthentication auth = LocalAuthentication();

Future<bool> doBiometricAuthentication({required String localizedReason}) async {
  // LINE 97 — LINT (`auth.authenticate(...)`)
  return auth
      .authenticate(localizedReason: localizedReason)
      .then((bool authenticated) => authenticated);
}

Future<bool> isBiometricsAuthenticationSupported() async {
  return auth.canCheckBiometrics.then((bool _) {
    // LINE 153 — LINT (`auth.isDeviceSupported()`)
    return auth.isDeviceSupported().then((bool deviceSupported) => deviceSupported);
  });
}

Future<List<BiometricType>?> getAvailableBiometrics() async {
  // LINE 182 — LINT (`auth.getAvailableBiometrics()`)
  return auth.getAvailableBiometrics().then((List<BiometricType> b) => b);
}
```

All four sites flag with:

```
[require_ios_face_id_usage_description] Biometric authentication detected. iOS requires
NSFaceIDUsageDescription in Info.plist for Face ID. {v4}
```

**Expected:** Zero diagnostics — the project's `Info.plist` already has the key.

**Frequency:** Always — every `LocalAuthentication`-typed expression and constructor reproduces it for this project, despite the plist being correct.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (`Info.plist` contains `<key>NSFaceIDUsageDescription</key>` — early-return guard should fire) |
| **Actual** | `[require_ios_face_id_usage_description]` reported on every `LocalAuthentication()` and `auth.<method>(...)` site |

---

## AST Context

```
CompilationUnit
  └─ TopLevelVariableDeclaration (auth)
      └─ VariableDeclaration
          └─ InstanceCreationExpression (LocalAuthentication())  ← reported (line 13)

CompilationUnit
  └─ FunctionDeclaration (doBiometricAuthentication)
      └─ Block
          └─ ReturnStatement
              └─ MethodInvocation (.authenticate)               ← reported (line 97)

… same shape for `isDeviceSupported` (153) and `getAvailableBiometrics` (182).
```

The reported node is the constructor / method invocation. The `runWithReporter` early-return guard runs once per file, BEFORE any visitor is registered. If the guard worked, none of those nodes would receive a visitor callback.

---

## Root Cause

The rule's early-return guard:

```dart
// ios_capabilities_permissions_rules.dart:702-710
final filePath = context.filePath;
final plistChecker = InfoPlistChecker.forFile(filePath);

if (plistChecker?.hasKey('NSFaceIDUsageDescription') ?? false) {
  return;
}
```

For visitors to register (and the lint to fire), the conditional MUST evaluate to `false`. That requires either:

- (A) `plistChecker` is `null` — `_findProjectRoot(...)` failed to find `pubspec.yaml` walking up from `context.filePath`.
- (B) `plistChecker` is non-null AND `hasKey('NSFaceIDUsageDescription')` returned `false` — content was loaded but the regex did not match.

### Hypothesis A: `_findProjectRoot` returns null because `context.filePath` is not a filesystem path

`InfoPlistChecker._toFilesystemPath` (info_plist_utils.dart:119-137) only converts `file:` URIs. Everything else is returned unchanged. If the analyzer passes a `package:saropa/utils/user/security/biometrics.dart`-style URI, `_findProjectRoot` walks up `package:saropa/...` segments — it never sees `pubspec.yaml` because `package:` is not a real filesystem prefix — and returns `null`.

The project trace for the failing reproducer is `d:/src/contacts/lib/utils/user/security/biometrics.dart` (Windows). With this raw filesystem path, the walk-up should find `d:/src/contacts/pubspec.yaml` in five iterations. So the leading hypothesis is that the analyzer is passing a non-filesystem URI form here.

A second variation of (A): on Windows, when `context.filePath` is `/d:/src/contacts/...` (leading slash from a normalized URI), `lastSlash <= 0` could break the loop too early when `current` becomes `/d:`.

### Hypothesis B: Cache holds a stale "no-key" snapshot

`InfoPlistChecker._cache` keys on `projectRoot` and invalidates by `_plistMtime` + `_plistSize`. If the plist was edited at the same mtime as a prior snapshot AND ended up the same size as a prior version that was missing the key (very unlikely but possible on Windows where mtime can be coarse), the cached `_infoPlistContent` would still be the old missing-key text. The size check makes this very unlikely for a real edit, but a Windows mtime granularity issue combined with a tooling write that landed an identical-size file could trip it.

### Hypothesis C: The walk-up finds a *closer* `pubspec.yaml`

If a pubspec.yaml exists at a path BELOW `d:/src/contacts/` and ABOVE the analyzed file (e.g., a `dependency_overrides/<pkg>/pubspec.yaml` somewhere in the walk), `_findProjectRoot` returns that nested package's directory, not the app root. That nested package has no `ios/Runner/Info.plist`, so `existsSync()` returns `false`, `_infoPlistContent` is `null`, and `hasKey` returns `true` — that branch would NOT cause the bug. So C does not match the symptom directly. Still worth ruling out by tracing.

---

## Suggested Fix

1. Make `_toFilesystemPath` reject any non-filesystem URI scheme (`package:`, `dart:`, etc.) explicitly, returning `null` so the caller can early-out instead of walking a fake path. Today it returns the unchanged string and quietly burns a walk-up.

2. In `_findProjectRoot`, return `null` if the input does not start with a recognizable filesystem prefix (drive letter, `/`, or UNC path).

3. Add Windows-path test fixtures: `d:/proj/lib/file.dart`, `D:\proj\lib\file.dart`, `/d:/proj/lib/file.dart` (URI-derived), and `package:foo/bar.dart` (must NOT walk up — must short-circuit to null).

4. Consider logging when `_findProjectRoot` returns null inside the rule's guard — currently the rule silently treats "no project root" as "no plist" and proceeds to flag, which is the worst-case default for downstream noise.

---

## Fixture Gap

`example*/lib/platforms/require_ios_face_id_usage_description_fixture.dart` should include:

1. **Project with NSFaceIDUsageDescription present** — `LocalAuthentication()`, `auth.authenticate(...)`, `auth.canCheckBiometrics`, `auth.isDeviceSupported()`, `auth.getAvailableBiometrics()` — expect NO lint at any of those sites.
2. **Project with NSFaceIDUsageDescription missing** — same constructor / method calls — expect LINT at each site.
3. **Cached project state changes** — first analysis with key missing, then plist edited to add key, then re-analyze — expect lint to disappear after re-analysis.
4. **Path normalization** — file resolved via `package:`-style URI, `file:` URI, Windows backslash path, Windows forward-slash path with drive letter — all should locate the same project root.

---

## Changes Made

(pending investigation)

---

## Tests Added

(pending)

---

## Commits

(pending)

---

## Environment

- saropa_lints version: 13.4.1 (resolved from `^13.3.2`)
- Triggering project: `d:/src/contacts` on Windows 11
- Dart SDK: project default
- Plist confirmed at: `d:/src/contacts/ios/Runner/Info.plist:89` — `<key>NSFaceIDUsageDescription</key>`
- Triggering file: `d:/src/contacts/lib/utils/user/security/biometrics.dart` — flagged at lines 13, 97, 153, 182

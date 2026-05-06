# BUG: `require_image_picker_permission_android` — False positive when manifest already declares CAMERA

**Status: Closed** (fixed in unreleased `main`; manifest gate + `pickVideo` 2026-04-26)

Created: 2026-04-26  
Closed: 2026-04-26  
Rule: `require_image_picker_permission_android`  
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (class `RequireImagePickerPermissionAndroidRule`)  
Severity: False positive — structural (rule did not read manifest)  
Rule version: v4 | Lint message: `{v4}`

---

## Summary

The rule warned on every `pickImage` / `pickVideo` call with `ImageSource.camera` even when `android.permission.CAMERA` was already present in `AndroidManifest.xml`.

---

## Resolution

`RequireImagePickerPermissionAndroidRule.runWithReporter` now uses `AndroidManifestChecker.forFile(context.filePath)` and returns early when no manifest is resolved, when `CAMERA` is already declared, or before registering visitors (mirrors `RequireImagePickerPermissionIosRule` plist gating). `pickVideo` is included alongside `pickImage` via `_cameraCapableMethods`.

`AndroidManifestChecker.clearCache()` added for tests.

Tests: `test/require_image_picker_permission_android_rule_test.dart` (manifest checker contract + metadata).

Fixture: `example/lib/widget_patterns/require_image_picker_permission_android_fixture.dart` with real `ImagePicker` calls; `example/android/app/src/main/AndroidManifest.xml` (minimal, no CAMERA) so BAD cases still lint in the example package.

---

## Original Report Content

### Summary (historical)

The rule fired on every `pickImage(source: ImageSource.camera)` call regardless of whether `<uses-permission android:name="android.permission.CAMERA"/>` already existed in the project's `AndroidManifest.xml`. The sibling iOS rule correctly gated on plist content; Android had no equivalent gate.

### Reproducer (downstream)

Consumer `contacts`: manifest with CAMERA + `ImagePicker().pickImage(source: ImageSource.camera)` still produced a lint.

### Root Cause (historical)

The manifest check was never wired into `runWithReporter`; emit was unconditional after AST match.

### Suggested fix (implemented)

Wire `AndroidManifestChecker.forFile`, short-circuit when `hasPermission('CAMERA')`, align `pickVideo` with iOS.

### Environment (historical)

- saropa_lints: 12.4.0 at report time  
- Dart SDK: 3.9.x

# BUG: `require_image_picker_permission_ios` — False positive when Info.plist already has camera key

**Status: Open**

Created: 2026-04-25  
Rule: `require_image_picker_permission_ios`  
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (class `RequireImagePickerPermissionIosRule`, ~L2111)  
Severity: False positive  
Rule version: v4 | Since: v2.3.3 | Updated: v4.14.0

---

## Summary

The rule warns that `NSCameraUsageDescription` is missing whenever `pickImage` / `pickVideo` uses `ImageSource.camera`, even when `ios/Runner/Info.plist` already defines that key. Downstream projects with a valid plist still see the diagnostic.

---

## Attribution Evidence

Positive grep (rule lives in this repo):

```bash
grep -rn "'require_image_picker_permission_ios'" lib/src/rules/
```

Example match:

```text
lib/src/rules/widget/widget_patterns_require_rules.dart:2130:    'require_image_picker_permission_ios',
```

- Rule defined in `lib/src/rules/widget/widget_patterns_require_rules.dart` at the `LintCode` name `'require_image_picker_permission_ios'`.
- Rule set exported from `lib/src/rules/all_rules.dart` via `export 'widget/widget_patterns_require_rules.dart';`.

---

## Reproducer (downstream)

In `contacts`:

- Camera usage exists:
  - `lib/components/contact/avatar/avatar_sheet_upload_section.dart`
  - `source: ImageSource.camera,`
- iOS camera key already exists:
  - `ios/Runner/Info.plist`
  - `<key>NSCameraUsageDescription</key>`

Yet the lint still reports missing camera permission.

---

## Expected vs Actual

- **Expected:** No diagnostic when `NSCameraUsageDescription` is present in the resolved `ios/Runner/Info.plist` for the project (same semantics as other plist-aware rules).
- **Actual:** Diagnostic is emitted regardless of plist content.

---

## Root Cause

`RequireImagePickerPermissionIosRule` only inspects the Dart AST: it matches `pickImage` / `pickVideo` with a `source` named argument equal to `ImageSource.camera` and calls `reporter.atNode(node)` with no project or plist lookup.

There is no `InfoPlistChecker` (or any plist read) in `widget_patterns_require_rules.dart` for this rule.

By contrast, `require_ios_permission_description` in `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart` already combines ImagePicker callsite analysis with `InfoPlistChecker.forFile` and `getMissingKeys`, and only reports when keys are actually missing.

---

## Suggested Fix

1. In `RequireImagePickerPermissionIosRule.runWithReporter`, obtain `InfoPlistChecker.forFile(context.filePath)` and report only when the checker indicates `NSCameraUsageDescription` is missing (mirror the `getMissingKeys` / `hasKey` pattern used in `ios_capabilities_permissions_rules.dart` for camera source).
2. Add a unit test (and optional `example/` fixture if the harness supports plist-on-disk for that test) where `ImageSource.camera` is present, a synthetic or temp project layout includes `ios/Runner/Info.plist` with `<key>NSCameraUsageDescription</key>`, and the expected result is **no lint**.
3. Longer term: if flavors use non-`ios/Runner/Info.plist` paths, extend `InfoPlistChecker` resolution; that is separate from this bug’s primary issue (no plist check at all).

---

## Related

- `require_ios_permission_description` — overlapping, plist-aware ImagePicker handling; consider whether both rules should stay enabled together once this rule reads the plist.

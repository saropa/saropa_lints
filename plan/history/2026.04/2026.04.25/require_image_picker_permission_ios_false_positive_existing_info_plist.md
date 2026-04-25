# BUG: `require_image_picker_permission_ios` — False positive when Info.plist already has camera key

**Status: Closed** (fixed in unreleased `main`; plist gate added 2026-04-25)

Created: 2026-04-25  
Closed: 2026-04-25  
Rule: `require_image_picker_permission_ios`  
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (class `RequireImagePickerPermissionIosRule`)  
Severity: False positive  
Rule version: v5 | Since: v2.3.3 | Updated: v4.14.0 (rule doc: v5)

---

## Summary

The rule warned that `NSCameraUsageDescription` was missing whenever `pickImage` / `pickVideo` used `ImageSource.camera`, even when `ios/Runner/Info.plist` already defined that key.

---

## Resolution

`RequireImagePickerPermissionIosRule.runWithReporter` now uses `InfoPlistChecker.forFile(context.filePath)` and reports only when `getMissingKeys(['NSCameraUsageDescription'])` is non-empty, matching `require_ios_permission_description` semantics.

Tests: `test/require_image_picker_permission_ios_rule_test.dart` (plist gate contract + metadata).

---

## Original Report Content

### Attribution Evidence

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

### Reproducer (downstream)

In `contacts`:

- Camera usage: `lib/components/contact/avatar/avatar_sheet_upload_section.dart` with `source: ImageSource.camera,`
- Plist: `ios/Runner/Info.plist` with `<key>NSCameraUsageDescription</key>`

### Root Cause (historical)

The rule only inspected the Dart AST and did not consult `InfoPlistChecker`.

### Related

- `require_ios_permission_description` — overlapping ImagePicker + plist logic; both may still emit when the key is genuinely missing (duplicate reminders possible).

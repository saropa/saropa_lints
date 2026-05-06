# `require_image_picker_permission_ios` — false positive: rule fires when Info.plist already contains `NSCameraUsageDescription`

**Status:** Fixed (Info.plist cache invalidation on size/mtime, whitespace-tolerant key match, `file:` URI path normalization; rule message `{v6}`.)

Filed: 2026-04-26
Rule: `require_image_picker_permission_ios`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line 2115, code at 2133–2172)
Severity: False positive (path resolution / plist read)
Rule version: v6 | Severity in code: WARNING | Impact: critical

---

## Summary

Rule fires on `pickImage(source: ImageSource.camera)` even when `ios/Runner/Info.plist` of the analyzed project contains the literal `<key>NSCameraUsageDescription</key>` line (the exact pattern `InfoPlistChecker.hasKey` searches for at `lib/src/info_plist_utils.dart:131`). On the contacts repository, the key is at `ios/Runner/Info.plist:96`, the file is readable, and `dart analyze` is run from the project root — yet the diagnostic still fires.

This means one of the following must be wrong:

1. `InfoPlistChecker.forFile(context.filePath)` is failing to resolve the project root on Windows;
2. The plist read is returning content that does not literally contain `<key>NSCameraUsageDescription</key>` (encoding / line-ending / cache pollution);
3. The cache (`_cache` at `lib/src/info_plist_utils.dart:29`) is holding a stale entry from a state where the key was missing.

---

## Attribution Evidence

```bash
$ grep -rn "'require_image_picker_permission_ios'" lib/src/rules/
lib/src/rules/widget/widget_patterns_require_rules.dart:2134:    'require_image_picker_permission_ios',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/widget/widget_patterns_require_rules.dart:2115` (`RequireImagePickerPermissionIosRule`)
**Rule class:** `RequireImagePickerPermissionIosRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`.

`ios/Runner/Info.plist:95–97`:

```xml
<!-- Camera access for contact/email photo capture (image_picker) -->
<key>NSCameraUsageDescription</key>
<string>Saropa uses your camera to take photos for contacts and emails.</string>
```

Dart code at `lib/components/contact/avatar/avatar_sheet_upload_section.dart:117`:

```dart
import 'package:image_picker/image_picker.dart';

Future<void> _pickFromCamera(BuildContext context) async {
  final XFile? photo = await ImagePicker().pickImage( // LINT — but should NOT lint (plist has key)
    source: ImageSource.camera,
    maxWidth: 1024,
    maxHeight: 1024,
  );
}
```

**Frequency:** Always — every `pickImage(source: ImageSource.camera)` site, even though the plist key exists.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. `InfoPlistChecker.forFile(<consumer-file-path>)` should walk up to `D:/src/contacts/`, locate `ios/Runner/Info.plist`, find `<key>NSCameraUsageDescription</key>`, return empty `getMissingKeys(['NSCameraUsageDescription'])`, and the rule should short-circuit at line 2162 (`if (missingCamera.isEmpty) return;`). |
| **Actual** | `[require_image_picker_permission_ios] Using ImageSource.camera requires NSCameraUsageDescription in Info.plist — missing it causes a crash or App Store rejection. {v4}` fires. |

---

## AST Context

```
MethodInvocation (ImagePicker().pickImage)
  └─ ArgumentList
      └─ NamedExpression (source: ImageSource.camera)  ← reported here
```

Detection logic (lines 2160–2171):

```dart
context.addMethodInvocation((MethodInvocation node) {
  if (!_cameraCapableMethods.contains(node.methodName.name)) return;
  if (missingCamera.isEmpty) return; // ← should short-circuit but doesn't

  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == 'source') {
      if (arg.expression.toSource() == 'ImageSource.camera') {
        reporter.atNode(node);
      }
    }
  }
});
```

The fact that emission reaches `reporter.atNode(node)` proves `missingCamera` is non-empty — meaning `getMissingKeys(['NSCameraUsageDescription'])` thinks the key is absent.

---

## Root Cause

### Hypothesis A: `_findProjectRoot` Windows path quirk

`InfoPlistChecker._findProjectRoot` (lib/src/info_plist_utils.dart:75–107) normalizes `\` → `/` then walks up looking for `pubspec.yaml`. If `context.filePath` arrives as a URI (`file:///D:/src/contacts/lib/...`) instead of a native path (`D:\src\contacts\lib\...`), the walk-up still works (the `:` and slashes are preserved), but the final `File('$projectRoot/ios/Runner/Info.plist')` becomes `File('file:///D:/src/contacts/ios/Runner/Info.plist')` which is not a valid local path on Windows. `existsSync()` returns `false`, `_infoPlistContent` is `null`, `hasInfoPlist` is `false`, `getMissingKeys` returns `[]`... wait — that returns empty.

Re-tracing: at `info_plist_utils.dart:138`, when `_infoPlistContent` is null, `getMissingKeys` returns `[]`. So `missingCamera.isEmpty` would be true → rule short-circuits → no diagnostic. **Hypothesis A would not produce the observed behavior.** (It would silently skip on URI paths.)

So either `_infoPlistContent` is non-null but doesn't contain `<key>NSCameraUsageDescription</key>`, or there is a separate path leading to non-empty `missingCamera`.

### Hypothesis B: plist content is read but the `<key>...</key>` substring search misses

`hasKey` at `info_plist_utils.dart:125–132`:

```dart
bool hasKey(String key) {
  if (_infoPlistContent == null) return true;
  return _infoPlistContent.contains('<key>$key</key>');
}
```

The contacts plist literally contains `<key>NSCameraUsageDescription</key>` on line 96 — exact match for `<key>NSCameraUsageDescription</key>`. So this should return `true`.

Possibilities for false negative:
- BOM / encoding issue: the plist starts with a BOM or non-UTF-8 chars and `readAsStringSync` decodes them differently. Unlikely on Windows-edited plists, but possible.
- Whitespace inside the tag: if the plist were ever generated with `<key >NSCameraUsageDescription</key>` or `<key>\n NSCameraUsageDescription\n</key>`, the literal substring would miss. The contacts plist does not have whitespace, but the rule is too brittle in general.

### Hypothesis C: cache pollution

`_cache` at `lib/src/info_plist_utils.dart:29` is process-global and never invalidated except via `clearCache()`. If the analyzer process started before the plist was edited (or while a different `Info.plist` was on disk), the cached `InfoPlistChecker` would hold stale `_infoPlistContent` for the lifetime of the analyzer process. Adding the key, then expecting the rule to clear, would silently fail because the cache never refreshes.

This is the most likely cause given the symptom: the rule fires consistently in IDE diagnostics (long-running analyzer process) but might not in fresh `dart analyze` runs.

### Hypothesis D: Windows project-root walk hits a sibling pubspec first

Path normalization on `D:\src\contacts\lib\components\contact\avatar\avatar_sheet_upload_section.dart` walks up:

```
D:/src/contacts/lib/components/contact/avatar  (no pubspec.yaml)
D:/src/contacts/lib/components/contact          (no pubspec.yaml)
D:/src/contacts/lib/components                  (no pubspec.yaml)
D:/src/contacts/lib                             (no pubspec.yaml)
D:/src/contacts                                 (pubspec.yaml ✓)
```

Then plist path = `D:/src/contacts/ios/Runner/Info.plist` ✓ exists.

But `dependency_overrides/arb_translate/` and similar nested packages have their own `pubspec.yaml`. If the analyzer ever passes a file from `dependency_overrides/...`, the walk-up would stop at the inner pubspec, and there is no `ios/Runner/Info.plist` under `dependency_overrides/arb_translate/`. That would yield `_infoPlistContent == null` → `getMissingKeys` returns `[]` → no diagnostic → not the observed behavior.

---

## Suggested Fix

Layered fixes from highest to lowest leverage:

1. **Make the `<key>...</key>` search whitespace-tolerant.** Replace the literal `contains('<key>$key</key>')` with a regex that allows incidental whitespace inside the tag:
   ```dart
   bool hasKey(String key) {
     if (_infoPlistContent == null) return true;
     final pattern = RegExp(r'<\s*key\s*>\s*' + RegExp.escape(key) + r'\s*<\s*/\s*key\s*>');
     return pattern.hasMatch(_infoPlistContent);
   }
   ```
2. **Invalidate the cache when the underlying plist file's mtime changes.** Store the plist file's `lastModifiedSync()` in the checker; on subsequent `forFile` lookups, compare and re-read on mismatch. This closes the cache-pollution hypothesis (most likely culprit).
3. **Log when a project root is found but the plist is missing or unreadable.** Currently the silent default of "assume OK" hides path/encoding bugs. A `developer.log` (already imported) at the read site would surface the real cause.
4. **Add a deterministic test for Windows path inputs** (`D:\\src\\contacts\\lib\\foo.dart` and `file:///D:/src/contacts/lib/foo.dart`) confirming both resolve to the same project root and find the plist.

(1) and (2) together close the bug regardless of which hypothesis is correct. (1) is a one-line behavioral relax. (2) is the real fix.

---

## Fixture Gap

The fixture at `example*/lib/widget/require_image_picker_permission_ios_fixture.dart` should include:

1. **Plist with `<key>NSCameraUsageDescription</key>`, code uses `pickImage(source: ImageSource.camera)`** — expect NO lint
2. **Plist without the key, code uses `pickImage(source: ImageSource.camera)`** — expect LINT
3. **Plist with whitespace variant `<key>\nNSCameraUsageDescription\n</key>`** — expect NO lint *(currently false positive)*
4. **Plist with the key, code uses `pickVideo(source: ImageSource.camera)`** — expect NO lint
5. **No `ios/` directory** — expect NO lint
6. **Plist mutated after first cache load** — expect rule to honor the new content (cache invalidation test)

---

## Downstream

Tracked in `contacts/` — `// ignore: require_image_picker_permission_ios` at `lib/components/contact/avatar/avatar_sheet_upload_section.dart:117` once this report exists.

---

## Environment

- saropa_lints version: 12.4.0
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
- Long-running analyzer process suspected (IDE) — not yet verified against fresh `dart analyze`.

---

## Resolution (archived from `bugs/` 2026-04-26)

Landed behavior: `InfoPlistChecker.forFile` normalizes `file:` URIs via `Uri.toFilePath`, re-reads `ios/Runner/Info.plist` when the on-disk stat snapshot changes (`modified` plus `size`, so same-mtime rapid writes still invalidate on Windows), clears pinned mtime/size on read failure so the next pass retries, and `hasKey` uses a whitespace-tolerant regex. Unit tests cover URI paths, whitespace keys, and stat-based cache refresh. `RequireImagePickerPermissionIosRule` diagnostic suffix is `{v6}`.

# Bug: `require_image_picker_permission_ios` fires false positive for gallery-only usage

**Status:** Fixed (Option B — match Android rule pattern)
**Component:** saropa_lints — `RequireImagePickerPermissionIosRule`
**Severity:** Medium — causes unnecessary warnings; following the correction message would add an unused iOS permission that alarms users
**File:** `lib/src/rules/widget/widget_patterns_require_rules.dart` (line 2004)

## Problem

The rule fires on **any** file that imports `image_picker`, regardless of which `ImageSource` is actually used. Its correction message tells developers to add both `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` to Info.plist.

This is wrong when the app only uses `ImageSource.gallery`. Adding `NSCameraUsageDescription` without ever accessing the camera:

1. **Alarms users** — iOS shows "this app may access your camera" in Settings > Privacy with no legitimate reason
2. **Risks App Store rejection** — Apple reviews flag declared permissions that are never exercised
3. **Erodes trust** — users see a camera permission on a screen that only picks photos from the library

The **Android companion rule** (`RequireImagePickerPermissionAndroidRule`, line 2057) does not have this problem. It specifically checks for `pickImage(source: ImageSource.camera)` calls and only fires when the camera source is actually used. The iOS rule should follow the same approach.

## Current behavior (iOS rule)

```dart
// RequireImagePickerPermissionIosRule.runWithReporter (line 2025)
context.addImportDirective((ImportDirective node) {
  if (reported) return;

  final uri = node.uri.stringValue ?? '';
  if (uri.contains('image_picker')) {
    reporter.atNode(node);  // Fires on import alone
    reported = true;
  }
});
```

Fires unconditionally on the import. Does not inspect how `ImagePicker` is used.

## Current behavior (Android rule — correct)

```dart
// RequireImagePickerPermissionAndroidRule.runWithReporter (line 2079)
context.addMethodInvocation((MethodInvocation node) {
  if (node.methodName.name != 'pickImage') return;

  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == 'source') {
      if (arg.expression.toSource() == 'ImageSource.camera') {
        reporter.atNode(node);  // Fires only on camera usage
      }
    }
  }
});
```

Only fires when `ImageSource.camera` is passed to `pickImage()`. Gallery-only usage is correctly ignored.

## Real-world trigger

In the Saropa contacts app, `lib/views/email/email_center_screen.dart` imports `image_picker` and only uses `ImageSource.gallery`:

```dart
final XFile? pick = await picker.pickImage(
  source: ImageSource.gallery,  // Gallery only — no camera
  maxWidth: 1920,
  maxHeight: 1080,
);
```

The iOS Info.plist correctly has `NSPhotoLibraryUsageDescription` and correctly omits `NSCameraUsageDescription`. The rule fires a false positive warning telling the developer to add a camera permission that should not be there.

## Expected behavior

The iOS rule should distinguish between gallery and camera usage, matching the Android rule's approach:

- `ImageSource.gallery` or `ImageSource.gallery` only → require `NSPhotoLibraryUsageDescription` only
- `ImageSource.camera` usage present → require both `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription`
- Both sources used → require both

## Fix options

### Option A: Split into source-aware checks (recommended)

Rewrite the iOS rule to inspect `pickImage()` calls like the Android rule does. Fire different messages depending on which `ImageSource` values are used:

```dart
@override
void runWithReporter(
  SaropaDiagnosticReporter reporter,
  SaropaContext context,
) {
  bool reportedCamera = false;
  bool reportedGallery = false;

  context.addMethodInvocation((MethodInvocation node) {
    if (node.methodName.name != 'pickImage') return;

    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'source') {
        final String source = arg.expression.toSource();
        if (source == 'ImageSource.camera' && !reportedCamera) {
          // Camera requires both NSCameraUsageDescription
          // and NSPhotoLibraryUsageDescription
          reporter.atNode(node);
          reportedCamera = true;
        } else if (source == 'ImageSource.gallery' && !reportedGallery) {
          // Gallery requires only NSPhotoLibraryUsageDescription
          reporter.atNode(node);
          reportedGallery = true;
        }
      }
    }
  });
}
```

This would need two separate `LintCode` instances — one for gallery (photo library permission only) and one for camera (camera + photo library permissions).

### Option B: Match Android rule's pattern exactly

Only warn about camera permission when `ImageSource.camera` is detected. Drop the gallery check entirely since `NSPhotoLibraryUsageDescription` is a well-known iOS requirement that most projects already have:

```dart
@override
void runWithReporter(
  SaropaDiagnosticReporter reporter,
  SaropaContext context,
) {
  context.addMethodInvocation((MethodInvocation node) {
    if (node.methodName.name != 'pickImage') return;

    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'source') {
        if (arg.expression.toSource() == 'ImageSource.camera') {
          reporter.atNode(node);
        }
      }
    }
  });
}
```

### Option C: Suppress with a comment (workaround, not a fix)

The consuming project can suppress the warning per-file, but this defeats the purpose of the rule and would need to be repeated in every file that imports `image_picker`.

## Impact

Any project using `image_picker` for gallery-only access (a common pattern for profile photos, email attachments, etc.) gets a false positive warning. Developers who follow the correction message will add an unnecessary `NSCameraUsageDescription` that:

- Makes users suspicious about camera access they never granted
- May trigger App Store review questions about unused permissions
- Creates a privacy policy obligation to explain camera access that does not exist

## Additional notes

- The rule's `applicableFileTypes` is `{FileType.widget}`, which means it won't fire in non-widget files. If `image_picker` is used in a service or utility class, the rule misses it entirely. Consider whether this restriction is intentional.
- The `pickVideo()` method also accepts `ImageSource.camera` and `ImageSource.gallery` but is not checked by either rule.
- `image_picker` also provides `pickMultiImage()` which is gallery-only by API design — the current rule falsely flags files using only this method too.

# BUG: `prefer_image_cropping` — fires when the body calls a camelCase helper containing `Crop` (e.g. `_pushCropScreen`)

**Status: Fixed (implemented)**

Created: 2026-04-25
Rule: `prefer_image_cropping`
File: `lib/src/rules/security/permission_rules.dart` (lines ~417–422)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: unknown

---

## Summary

The "has cropping?" check uses word-boundary regexes (`\bcrop\b`,
`\bcropper\b`, `\bImageCropper\b`, `\bcropImage\b`) against the function
body. Word-boundaries (`\b`) do not split camelCase, so a body that calls
`_pushCropScreen(...)` or `openCropDialog(...)` — both of which DO route the
picked image through cropping — fails every regex. The rule reports as if
no cropping is present.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_image_cropping'" lib/src/rules/
# lib/src/rules/security/permission_rules.dart:353:    'prefer_image_cropping',
```

**Emitter registration:** `lib/src/rules/security/permission_rules.dart:353`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
import 'package:image_picker/image_picker.dart';

class AvatarUploadSection {
  Future<void> pushCropScreen(Uint8List bytes) async { /* crop UI */ }

  /// Picks a photo and routes the bytes through the cropping screen.
  Future<void> _pickAvatarFromCamera() async {
    // LINT — but should NOT lint
    // Bytes ARE routed through `_pushCropScreen` immediately after pickImage,
    // but \bcrop\b doesn't match within the camelCase identifier.
    final XFile? photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (photo == null) return;
    final Uint8List bytes = await photo.readAsBytes();
    await _pushCropScreen(bytes); // <-- IS the cropping step, but invisible to \bcrop\b
  }

  Future<void> _pushCropScreen(Uint8List bytes) async {
    // pushes a route to the crop UI; opens an `ImageCropper`-equivalent screen
  }
}
```

The body source contains `_pushCropScreen` literally. `\bcrop\b` requires a
word boundary on BOTH sides of `crop` — within `pushCropScreen`, `Crop` is
flanked by lowercase + camelCase letters with no intervening non-word
character, so no boundary, no match.

`isProfileContext` correctly fires on the body keyword `avatar` (in the
class name and method name), so the rule reaches the cropping check. The
cropping check fails — false positive.

**Frequency:** Always — every project that names its crop helper using
camelCase (`_pushCropScreen`, `_navigateToCropper`, `openCropDialog`,
`runImageCropFlow`, etc.) is flagged even when cropping IS happening.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `_pushCropScreen` is the cropping step |
| **Actual** | `[prefer_image_cropping] Profile/avatar image picked without cropping…` reported on the `pickImage` call |

---

## AST Context

```
MethodDeclaration (_pickAvatarFromCamera)
  └─ FunctionBody
      └─ Block
          └─ ExpressionStatement
              └─ AwaitExpression
                  └─ MethodInvocation (pickImage) ← reported here
          └─ ...
          └─ ExpressionStatement
              └─ AwaitExpression
                  └─ MethodInvocation (_pushCropScreen) ← cropping evidence the rule misses
```

The rule reads `body.toSource()` and runs regex over it. AST node walking
is not used for the cropping check; if it were, the `MethodInvocation`
named `_pushCropScreen` would be visible.

---

## Root Cause

`permission_rules.dart:417-422`:

```dart
if (RegExp(r'\bcropper\b').hasMatch(bodySource) ||
    RegExp(r'\bcrop\b').hasMatch(bodySource) ||
    RegExp(r'\bImageCropper\b').hasMatch(bodySource) ||
    RegExp(r'\bcropImage\b').hasMatch(bodySource)) {
  return; // Has cropping
}
```

`\b` in Dart's `RegExp` is a word boundary between `\w` and `\W`. CamelCase
identifiers are all `\w` characters, so `\b` never fires inside them. Every
camelCase helper containing the word `Crop` is structurally invisible.

The earlier `_profileContextKeywords` check uses
`RegExp.escape(keyword)` wrapped in `\b…\b` for the same reason — but the
`bodySource` it runs against is `.toLowerCase()`, so `pushcropscreen`
matches `\bcrop\b` even less because the boundary still fails. (`.toLowerCase()`
preserves the lack of word boundary.)

---

## Suggested Fix

### Option A — relax the word boundary

Drop the trailing `\b` (or both) so camelCase suffixes are accepted:

```dart
if (RegExp(r'\bCrop', caseSensitive: false).hasMatch(bodySource) ||
    RegExp(r'\bImageCrop', caseSensitive: false).hasMatch(bodySource)) {
  return;
}
```

This matches `crop`, `cropper`, `cropImage`, `pushCropScreen`,
`navigateToCropper`, etc. Trade-off: it would also match `cropdust` or
`crop_circle` — neither of which is meaningful here. Risk is low.

### Option B — switch the cropping check to AST visitor

Walk the function body for `MethodInvocation` nodes whose `methodName.name`
case-insensitively contains `crop`. This is the durable fix and aligns with
the project's stated preference (no string matching for types — see
`BUG_REPORT_GUIDE.md`).

```dart
bool _bodyHasCropCall(FunctionBody body) {
  final visitor = _CropCallVisitor();
  body.accept(visitor);
  return visitor.found;
}

class _CropCallVisitor extends RecursiveAstVisitor<void> {
  bool found = false;
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final lower = node.methodName.name.toLowerCase();
    if (lower.contains('crop')) found = true;
    super.visitMethodInvocation(node);
  }
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final lower = node.constructorName.type.name.lexeme.toLowerCase();
    if (lower.contains('crop')) found = true;
    super.visitInstanceCreationExpression(node);
  }
}
```

Recommend Option A as the immediate hot-patch, Option B for the next major
revision.

---

## Fixture Gap

The fixture at
`example*/lib/security/prefer_image_cropping_fixture.dart` should include:

1. `pickImage` followed by direct `ImageCropper().cropImage(...)` — expect
   NO lint (already covered).
2. `pickImage` followed by `await _pushCropScreen(bytes)` (camelCase helper
   that opens a crop screen) — **expect NO lint** (currently flagged as
   bug).
3. `pickImage` followed by `await openCropDialog(bytes)` — expect NO lint.
4. `pickImage` followed by `await navigateToCropper()` — expect NO lint.
5. `pickImage` with no cropping at all — expect LINT.
6. `pickImage` in non-avatar context (e.g. attachment upload) — expect NO
   lint regardless of cropping (already covered by `isProfileContext`).

---

## Environment

- saropa_lints version: see `pubspec.yaml`
- Triggering project: `D:/src/contacts`
- Triggering file: `lib/components/contact/avatar/avatar_sheet_upload_section.dart` (~L116, ~L139)

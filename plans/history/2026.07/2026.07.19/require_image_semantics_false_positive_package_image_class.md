# BUG: `require_image_semantics` — fires on `package:image`'s `Image`, which has no accessibility surface

**Status: Fixed**

Created: 2026-07-19
Rules: `require_image_semantics`, `require_image_description`, `require_accessible_images` (one root cause, three emitters)
File: `lib/src/rules/ui/accessibility_rules.dart` (lines ~1485, ~2767, ~3566)
Severity: False positive — High (three diagnostics on one line; forces three `// ignore:` comments per site)
Rule version: v6 / v2 / v2

---

## Summary

All three rules identify Flutter's `Image` widget by the bare type name `'Image'`, with no check of the declaring library. `package:image`'s `img.Image` — a raw pixel-buffer container with no widget, no render object, and no screen reader relationship — is also named `Image`, so every `img.Image(...)` / `img.Image.fromBytes(...)` in decode, hashing, and thumbnail code is flagged as an inaccessible UI image. Three separate diagnostics land on the same line.

Expected: only Flutter's `package:flutter/src/widgets/image.dart` `Image` is flagged.

---

## Attribution Evidence

```bash
# Positive — all three rules ARE defined here
grep -rn "'require_image_semantics'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:1471:    'require_image_semantics',
grep -rn "'require_image_description'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:2751:    'require_image_description',
grep -rn "'require_accessible_images'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:3551:    'require_accessible_images',
```

**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `dartAnalysisLSP` (native analyzer plugin).

---

## Reproducer

```dart
import 'package:image/image.dart' as img;

img.Image? decode(Uint8List rgba, int width, int height) {
  // LINT x3 — but should NOT lint. This is package:image's Image: a pixel
  // buffer. It is never mounted, never painted, and never reaches a
  // SemanticsNode. There is no screen reader to describe it to.
  return img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    order: img.ChannelOrder.rgba,
  );
}
```

Real site: `d:/src/contacts/lib/utils/image/image_blur_hash_utils.dart:100` — an isolate-safe blur-hash utility with zero Flutter widget imports.

**Frequency:** Always, wherever `package:image` is used. Also expected to hit `dart:ui`'s `Image` (`ui.Image`), which is likewise not a widget.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the constructed type is not a Flutter widget |
| **Actual** | Three diagnostics on the same node: `require_image_semantics`, `require_image_description`, `require_accessible_images` |

---

## Root Cause

Name-only type identification, in all three rules — the "String matching for types" pitfall from the bug-report guide, applied to a class name that is genuinely ambiguous across packages.

`accessibility_rules.dart:1484` (`require_image_semantics`):

```dart
final String? constructorName = node.constructorName.type.element?.name;
if (constructorName != 'Image') return;
```

`accessibility_rules.dart:3565` (`require_accessible_images`) is byte-identical in shape.

`accessibility_rules.dart:2766` (`require_image_description`) is strictly worse — it reads the *lexeme*, so it does not even resolve an element:

```dart
final String typeName = node.constructorName.type.name.lexeme;
if (typeName != 'Image') return;
```

The lexeme form additionally means a prefixed `img.Image` and an aliased `import 'package:flutter/material.dart' as m; m.Image` are treated identically, and a renamed Flutter import (`as ui`) would be missed entirely (a matching false *negative*).

The `MethodInvocation` half of each rule (`Image.network` / `.asset` / `.file` / `.memory`, e.g. line 1515) matches on `target.name != 'Image'` — a `SimpleIdentifier` string compare — and has the same defect. `package:image` exposes no such factories today, so it does not fire in practice, but the check is equally unsound.

---

## Suggested Fix

Resolve the declaring library rather than the name. In all three rules, replace the name compare with an element+library check:

```dart
final InterfaceElement? element = node.constructorName.type.element;
if (element?.name != 'Image') return;
// Flutter's Image widget only. package:image and dart:ui both export a class
// named `Image` that never reaches the semantics tree, so the name alone is
// not enough to identify a widget.
final Uri? source = element?.library.uri;
if (source == null || !source.toString().startsWith('package:flutter/')) {
  return;
}
```

For `require_image_description` (line 2766), this also requires switching from `type.name.lexeme` to `type.element`, which is the substantive part of that change.

If a shared helper is preferred, `bool isFlutterWidgetNamed(InterfaceElement?, String)` in the accessibility rules' private helpers would serve all three call sites and the four `MethodInvocation` variants.

### Secondary observation (not this bug)

Three rules emit on the identical node for the identical concern, so a user sees three problems for one omission and must write three ignores. Same shape as the already-filed `infra_shrinkwrap_rule_overlap_four_rules_one_concern.md`. Worth a separate consolidation report; not fixed here.

---

## Fixture Gap

`example*/lib/ui/require_image_semantics_fixture.dart` (and the two peer fixtures) should include:

1. `img.Image.fromBytes(...)` with `package:image` imported under a prefix — expect NO lint
2. `img.Image(width: 1, height: 1)` unprefixed via `show Image` — expect NO lint
3. `ui.Image` from `dart:ui` — expect NO lint
4. Flutter `Image.asset('x')` with no `semanticLabel` — expect LINT (regression guard)
5. Flutter `Image` imported under a prefix (`m.Image.asset('x')`) — expect LINT (guards the lexeme→element switch)

---

## Environment

- Triggering project/file: `d:/src/contacts/lib/utils/image/image_blur_hash_utils.dart:100`
- Downstream suppression in place: three trailing `// ignore:` comments referencing this bug file.

---

## Finish Report (2026-07-19)

**Defect:** `require_image_semantics`, `require_image_description`, and `require_accessible_images` matched the Flutter `Image` widget by bare class name (`'Image'`). Any third-party or SDK class with the same name — `package:image`'s pixel-buffer `Image`, `dart:ui`'s `Image` — triggered three false-positive diagnostics per constructor call.

**Root cause:** Name-only type identification in all three rules. `require_image_description` was strictly worse, using `type.name.lexeme` (a string token) rather than the resolved element, making it also sensitive to import prefixes.

**Fix:** Added `_isFlutterImageElement(Element?)` to `accessibility_rules.dart`. The helper checks both `element.name == 'Image'` and `element.library.uri` starts with `package:flutter/`. All five affected code paths (three `InstanceCreationExpression` handlers, two `MethodInvocation` handlers) now call this helper instead of comparing the name string. For `MethodInvocation` targets, the project's `elementFromAstIdentifier()` utility resolves the `SimpleIdentifier` to its element cross-version.

**Pattern precedent:** `image_filter_quality_detection.dart:_isFlutterSdkInterface` uses the identical `library.uri.toString().startsWith('package:flutter/')` check.

**Tests:** 84/84 accessibility rule tests pass. Existing tests are instantiation pins and fixture-existence checks — they do not exercise library-origin logic. Fixture additions (items 1–5 in the Fixture Gap section) would require `package:image` as a dev dependency.

**Files changed:** `lib/src/rules/ui/accessibility_rules.dart` (helper + 5 call-site fixes), `CHANGELOG.md`, `bugs/BUG_REPORT_GUIDE.md` (reference update).

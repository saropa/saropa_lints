# BUG: `require_cached_image_error_widget` — fires when `errorBuilder` is used (deprecated `errorWidget` is the only recognized parameter)

**Status: Fixed**

Created: 2026-04-25
Rule: `require_cached_image_error_widget`
File: `lib/src/rules/media/image_rules.dart` (line ~1019)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: unknown

---

## Summary

`CachedNetworkImage` now exposes `errorBuilder` as the new API and deprecates
`errorWidget`. The rule's detector at `image_rules.dart:1019` only recognizes
`errorWidget`, so any code that follows the upstream deprecation guidance is
flagged as missing an error widget — even when it has correct error UI wired
through `errorBuilder`.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_cached_image_error_widget'" lib/src/rules/
# lib/src/rules/media/image_rules.dart:1000:    'require_cached_image_error_widget',
```

**Emitter registration:** `lib/src/rules/media/image_rules.dart:1000`
**Rule class:** `RequireCachedImageErrorWidget` (the class registered to that LintCode)
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

class Example extends StatelessWidget {
  const Example({super.key});

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint (errorBuilder satisfies the intent)
    return CachedNetworkImage(
      imageUrl: 'https://example.com/img.png',
      placeholder: (context, url) => const SizedBox.shrink(),
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
        return const Icon(Icons.broken_image);
      },
    );
  }
}
```

`errorBuilder` is the new upstream API; `errorWidget` is deprecated and
fires `deprecated_member_use` if you switch back to satisfy this rule. The
two diagnostics are mutually exclusive — either you trip
`require_cached_image_error_widget` or you trip `deprecated_member_use`.

**Frequency:** Always — every `CachedNetworkImage` site that uses the new API.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `errorBuilder` satisfies the "image must always render something on failure" intent |
| **Actual** | `[require_cached_image_error_widget] CachedNetworkImage without errorWidget...` reported on the `CachedNetworkImage` node |

---

## AST Context

```
ReturnStatement
  └─ InstanceCreationExpression (CachedNetworkImage)
      └─ ArgumentList
          ├─ NamedExpression (imageUrl)
          ├─ NamedExpression (placeholder)
          └─ NamedExpression (errorBuilder)   ← rule does not recognize this name
```

Rule visitor at `image_rules.dart:1018` walks every `NamedExpression` in
`node.argumentList.arguments` looking only for `name.label.name == 'errorWidget'`.

---

## Root Cause

### Hypothesis A: detector enumerates `errorWidget` only

Lines 1018–1023 of `image_rules.dart`:

```dart
for (final arg in node.argumentList.arguments) {
  if (arg is NamedExpression && arg.name.label.name == 'errorWidget') {
    hasErrorWidget = true;
    break;
  }
}
```

The `errorBuilder` parameter (the new upstream API) is not in the accepted set,
so a `CachedNetworkImage` that has `errorBuilder: ...` but no `errorWidget:`
fails the check. This is the root cause.

---

## Suggested Fix

Treat both names as satisfying the rule:

```dart
for (final arg in node.argumentList.arguments) {
  if (arg is NamedExpression) {
    final String name = arg.name.label.name;
    if (name == 'errorWidget' || name == 'errorBuilder') {
      hasErrorWidget = true;
      break;
    }
  }
}
```

Update the rule's `LintCode` `correctionMessage` to mention both, e.g.
"Add `errorWidget` (legacy) or `errorBuilder` (preferred)…".

Optionally also accept `errorListener` if the package still exposes it, but
`errorBuilder` is the documented replacement.

---

## Implemented

- Updated `lib/src/rules/media/image_rules.dart` so
  `require_cached_image_error_widget` accepts either `errorWidget` or
  `errorBuilder` as valid error fallbacks.
- Updated the lint wording to refer to "error fallback" and to recommend
  `errorBuilder` as the preferred API.
- Expanded
  `example/lib/image/require_cached_image_error_widget_fixture.dart` with:
  - `errorBuilder`-only case (no lint expected)
  - both `errorWidget` + `errorBuilder` transitional case (no lint expected)
- Added a regression note in `test/false_positive_fixes_test.dart` documenting
  this false-positive fix.

### Verification

- `dart test test/image_rules_test.dart test/false_positive_fixes_test.dart`
  passes after the fix.

---

## Fixture Gap

The fixture at `example*/lib/media/require_cached_image_error_widget_fixture.dart`
should include:

1. `CachedNetworkImage` with only `errorWidget:` — expect NO lint (legacy
   path).
2. `CachedNetworkImage` with only `errorBuilder:` — **expect NO lint** (new
   API; currently flagged as bug).
3. `CachedNetworkImage` with both — expect NO lint (transitional).
4. `CachedNetworkImage` with neither — expect LINT.

---

## Environment

- saropa_lints version: see `pubspec.yaml`
- Triggering project: `D:/src/contacts`
- Triggering file: `lib/components/primitive/image/common_network_image.dart` (line ~244 — `errorBuilder` in use)

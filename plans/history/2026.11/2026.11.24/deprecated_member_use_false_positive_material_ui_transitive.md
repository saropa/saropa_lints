# BUG: `deprecated_member_use` — Transitive false positive after material_ui migration

**Status: Open**

Created: 2026-11-23
Rule: `deprecated_member_use` (Dart SDK analyzer, NOT saropa_lints)
Severity: False positive
Source: `dartAnalysisLSP` / `dart`

---

## Summary

After migrating all imports from `package:flutter/material.dart` to `package:material_ui/material_ui.dart` (the official replacement per Flutter 3.47+), the `deprecated_member_use` warning persists. The analyzer follows the transitive dependency chain — `material_ui` internally references `flutter/material.dart` — and reports the deprecation on the consumer's import line, even though the consumer is using the recommended replacement.

---

## Attribution

This is a **Dart SDK analyzer** diagnostic, not a saropa_lints rule. Owner: `dartAnalysisLSP`, source: `dart`.

Filed here for tracking since it affects 19 files across saropa_dart_utils (9 lib, 10 test) and the warnings cannot be resolved at the consumer level.

---

## Reproduction

1. Flutter SDK 3.50.0, Dart SDK 3.14.0
2. `pubspec.yaml`: `material_ui: ^1.11.1`, `flutter: ">=3.47.0"`
3. Source file: `import 'package:material_ui/material_ui.dart';`
4. Analyzer reports: `'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead.`

The file already uses `material_ui` — the warning is from the transitive chain.

---

## Affected Files (19)

### lib/ (9 files)
- `lib/datetime/date_time_bounds_extensions.dart`
- `lib/datetime/date_time_calendar_extensions.dart`
- `lib/datetime/date_time_comparison_extensions.dart`
- `lib/datetime/date_time_range_utils.dart`
- `lib/datetime/iso_interval_parse_utils.dart`
- `lib/flutter/color_extensions.dart`
- `lib/flutter/material_color_utils.dart`
- `lib/gesture/swipe_properties.dart`
- `lib/niche/dark_colors.dart`

### test/ (10 files)
- `test/color/material_shade_test.dart`
- `test/datetime/date_time_bounds_extensions_test.dart`
- `test/datetime/date_time_calendar_extensions_test.dart`
- `test/datetime/date_time_comparison_extensions_test.dart`
- `test/datetime/date_time_extensions_test.dart`
- `test/datetime/date_time_range_utils_test.dart`
- `test/datetime/iso_interval_parse_utils_test.dart`
- `test/flutter/color_light_test.dart`
- `test/flutter/color_readable_test.dart`
- `test/flutter/color_to_color_test.dart`
- `test/flutter/color_to_hex_test.dart`
- `test/flutter/material_color_utils_test.dart`
- `test/niche/dark_colors_test.dart`

---

## Workaround

None available at the consumer level. The fix must come from either:
1. The `material_ui` package removing its internal dependency on `flutter/material.dart`
2. The Dart analyzer not propagating deprecation warnings through transitive re-exports

---

## Closed (2026-11-24)

Not a saropa_lints rule. `deprecated_member_use` is a Dart SDK analyzer diagnostic (source `dart`); no rule in lib/ declares it, so nothing here can fix or suppress it. Report upstream to the owning package (material_ui) or dart-lang/sdk.

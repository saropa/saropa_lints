# Plan: new `image_picker` lint rules

**Package:** image_picker ^1.2.2 (Saropa Contacts). **saropa_lints coverage:** none (new file).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `image_picker_unchecked_null_result` | correctness | `pickImage`/`pickVideo`/`pickMedia` return value stored/used without null guard | report-only | ERROR | only fires when static type of result usage is non-nullable; skip if result flows into `?.` chain or explicit null-check |
| `image_picker_missing_retrieve_lost_data` | correctness | `ImagePicker` instance created / `pickImage`/`pickVideo` called in a file that contains no `retrieveLostData` call | report-only | WARNING | skip if file is not Android-targeted or is a test file |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** cross-file lifecycle (call in startup file) FPs; file-level guard only.
| `image_picker_missing_image_quality` | best-practice | `pickImage` or `pickMedia` (single image) call with no `imageQuality` argument | report-only | WARNING | skip if `maxWidth`/`maxHeight` also absent (caller may be intentional full-res); skip non-image pickers (`pickVideo`) |
| `image_picker_missing_max_dimensions` | best-practice | `pickImage`/`pickMedia` call with no `maxWidth` AND no `maxHeight` argument | report-only | INFO | skip if `imageQuality` is present (caller is already size-conscious) |
| `image_picker_invalid_image_quality` | correctness | `imageQuality` argument is a literal integer outside 0–100 | mechanical fix: clamp to 0 or 100 | ERROR | only triggers on integer literals; ignore named constants / runtime expressions |
| `image_picker_unawaited_pick` | correctness | `pickImage`/`pickVideo`/`pickMedia`/`pickMultiImage`/`pickMultipleMedia` call NOT prefixed with `await` and NOT assigned into a `Future` variable | report-only | ERROR | skip if inside an unawaited helper intentionally; check that parent expression is not `unawaited(...)` wrapper |
> **VALIDATION (2026-06-11) — DROP (overlap):** largely subsumed by `avoid_unawaited_future` (async_rules.dart:3297).
| `image_picker_camera_source_without_support_check` | best-practice | `pickImage`/`pickVideo` with `source: ImageSource.camera` and no adjacent `supportsImageSource` guard | report-only | WARNING | skip if file imports `dart:io` and uses `Platform.isAndroid`/`Platform.isIOS` guard already |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** Platform.* heuristic misses helper-wrapped guards.
| `image_picker_lost_data_empty_check_missing` | correctness | `retrieveLostData()` call where `LostDataResponse` result is NOT checked with `.isEmpty` before accessing `.files` or `.exception` | report-only | WARNING | only fires when `.files`/`.exception` are accessed on the same response variable without an `isEmpty` check above |
| `image_picker_multi_result_unchecked_empty` | correctness | `pickMultiImage`/`pickMultipleMedia` result used with `.first`/`[0]`/`.last` without an `isNotEmpty`/`isEmpty` guard | mechanical fix: wrap with `if (result.isNotEmpty)` | ERROR | only fires on list element access; skip if already guarded by `.isNotEmpty` / `length > 0` check |
> **VALIDATION (2026-06-11) — OVERLAP:** `avoid_unsafe_collection_methods` (collection_rules.dart:386) already covers .first/.last/.single; keep ONLY the `[index]` indexer delta.

---

## Rule detail

### `image_picker_unchecked_null_result`

- **What/why:** `pickImage`, `pickVideo`, and `pickMedia` all return `Future<XFile?>` — the `XFile?` is nullable because the user can cancel the picker. Code that ignores the `?` and immediately calls `.path`, `.name`, `.readAsBytes()` etc. on the result without a null check throws a `NoSuchMethodError` at runtime. This is the single most common reported crash pattern with this plugin.
- **Detection (AST, type-safe):** match `MethodInvocation` where `methodName.name` is `pickImage`, `pickVideo`, or `pickMedia` AND the resolved element's enclosing library URI is `package:image_picker/image_picker.dart`. Then walk the parent chain: if the result is immediately accessed via `.` (a `PropertyAccess` or chained `MethodInvocation`) with no intervening `?.` or explicit `if (x == null)` / `if (x != null)` guard, report at the access site. Do NOT match if the result is passed to `?.` or the variable is declared with explicit type `XFile?` followed by a later null-check branch.
- **Fix:** report-only. The null-check pattern (early return vs `?.` vs non-null assert) is caller-intent-dependent; a mechanical rewrite would be wrong in too many cases.
- **False positives:** two traps: (a) the developer stores the result as `XFile?` and uses it later inside an `if`-guard in a different statement — avoid by checking the full enclosing function body, not just adjacent statements; (b) Dart non-null assertion `!` is a conscious decision — do NOT flag `image!.path`.

---

### `image_picker_missing_retrieve_lost_data`

- **What/why:** On Android, when the OS kills the app while an image/video Intent is active (low-memory process death), the data returned from the picker is delivered the *next time the app starts*, not to the original `pick*` call site. The only way to collect it is `retrieveLostData()`. Apps that never call it silently drop user-selected media after any process death. The official README marks this as "required" on Android.
- **Detection (AST, type-safe):** file-level check. Collect all `MethodInvocation` nodes in the compilation unit. If any node resolves to `ImagePicker.pickImage`, `pickVideo`, `pickMedia`, `pickMultiImage`, or `pickMultipleMedia` (element library URI == `package:image_picker/image_picker.dart`) AND no node in the same file resolves to `ImagePicker.retrieveLostData`, report on the first pick-method call site found.
- **Fix:** report-only. The `retrieveLostData` pattern requires a `LostDataResponse` handler integrated into the app's startup lifecycle — there is no safe mechanical insertion.
- **False positives:** test files (`path.endsWith('_test.dart')`) and files under `test/` or `example*/` should be skipped. Also skip if `ProjectContext.isTestFile(path)` returns true.

---

### `image_picker_missing_image_quality`

- **What/why:** Without `imageQuality`, `pickImage` returns the full-resolution image (commonly 10–50 MB on modern phones). Loading it uncompressed into memory for display or upload causes OOM errors and UI jank. Setting `imageQuality` to 70–85 typically reduces size by 80–90% with negligible visual loss.
- **Detection (AST, type-safe):** match `MethodInvocation` where `methodName.name` is `pickImage` or `pickMedia` AND library URI is `package:image_picker/image_picker.dart`. Check `argumentList.arguments` for a `NamedExpression` with label `imageQuality`. If absent, report on the method name node.
- **Fix:** report-only. The right value is app-domain-specific (a profile photo wants ~85; a thumbnail wants ~50).
- **False positives:** if the call already passes `maxWidth` AND `maxHeight` the risk is partially mitigated (dimensions are bounded); downgrade to INFO or suppress. Never fire on `pickVideo`, `pickMultiImage`, `pickMultipleMedia` — those have no `imageQuality` parameter.

---

### `image_picker_missing_max_dimensions`

- **What/why:** Even with `imageQuality`, a full-8K-sensor image decoded in memory stresses the Flutter image pipeline. `maxWidth`/`maxHeight` clamp the pixel dimensions before the JPEG encode, which reduces memory proportionally to area. The two constraints (`imageQuality` + `maxWidth`/`maxHeight`) are complementary: quality controls byte size, dimensions control decoded RAM.
- **Detection (AST, type-safe):** same as above — `pickImage` / `pickMedia` call from `package:image_picker`. Check `argumentList.arguments` for `maxWidth` OR `maxHeight`. If neither is present AND `imageQuality` is also absent, report INFO.
- **Fix:** report-only.
- **False positives:** skip if `imageQuality` is present (addressed by `image_picker_missing_image_quality` already). This rule fires only when the developer has set no size constraint at all.

---

### `image_picker_invalid_image_quality`

- **What/why:** `imageQuality` is asserted at runtime to be in `[0, 100]`. An out-of-range literal (e.g. `imageQuality: 150` or `imageQuality: -1`) throws an `AssertionError` in debug mode and produces a native crash in release mode on iOS (iOS 16+ had a confirmed crash). The valid range is documented in the plugin source.
- **Detection (AST, type-safe):** match `NamedExpression` where `name.label.name == 'imageQuality'` inside a `MethodInvocation` that resolves to `package:image_picker` pick methods. Check that `expression` is an `IntegerLiteral` with numeric value < 0 or > 100.
- **Fix:** mechanical — clamp to 0 or 100 (whichever boundary was crossed) via a simple literal replacement. Example: `imageQuality: 150` → `imageQuality: 100`.
- **False positives:** skip for named constants and any non-literal expression (cannot statically evaluate at lint time). Only trigger on raw integer literals.

---

### `image_picker_unawaited_pick`

- **What/why:** `pickImage` and its siblings return `Future<XFile?>` / `Future<List<XFile>>`. A call without `await` and without assigning to a variable typed as `Future` produces a fire-and-forget that silently discards the user's media choice. It also causes the "already_active" `PlatformException` if the picker is opened again before the discarded future settles.
- **Detection (AST, type-safe):** match `MethodInvocation` whose `methodName.name` is one of `pickImage`, `pickVideo`, `pickMedia`, `pickMultiImage`, `pickMultipleMedia` and the enclosing library is `package:image_picker`. Check that the invocation's parent is an `ExpressionStatement` (meaning the return value is discarded) and the statement is NOT wrapped in `unawaited(...)` (which is intentional ignore). Also ensure the enclosing function is `async` — a non-async function cannot `await`, so the FP risk is lower but the call is still wrong.
- **Fix:** report-only. Inserting `await` is mechanical but requires the enclosing function to be `async`, which may need its own signature change — too broad for an auto-fix.
- **False positives:** `unawaited(picker.pickImage(...))` is an explicit intent; do NOT flag it.

---

### `image_picker_camera_source_without_support_check`

- **What/why:** `ImageSource.camera` is not supported on web (`dart:html` file input opens the gallery) and throws `UnimplementedError` on Windows and Linux. The package provides `supportsImageSource(ImageSource.camera)` to check at runtime. Code that calls `pickImage(source: ImageSource.camera)` unconditionally will crash or behave unexpectedly on unsupported platforms.
- **Detection (AST, type-safe):** match `MethodInvocation` resolving to `ImagePicker.pickImage` or `ImagePicker.pickVideo` (library URI `package:image_picker`) where the `argumentList` contains `source: ImageSource.camera`. Then check the enclosing function (up to the nearest function body) for any call to `supportsImageSource` on an `ImagePicker` instance from the same library. If absent, report.
- **Fix:** report-only. Inserting a guard requires understanding the surrounding control flow.
- **False positives:** if the file has a broad `Platform.isAndroid || Platform.isIOS` guard wrapping the whole pick call, the risk is already handled. Check for a `Platform.*` guard in the enclosing `if`-condition or function. This is a heuristic; mark the check explicitly in the rule implementation comment.

---

### `image_picker_lost_data_empty_check_missing`

- **What/why:** `LostDataResponse` has an `.isEmpty` property that returns true when no lost data exists. Accessing `.files` or `.exception` without checking `.isEmpty` first will either return `null` (silent no-op if unchecked) or throw. The official documentation's recommended pattern always starts with `if (response.isEmpty) return;` before any property access.
- **Detection (AST, type-safe):** match `MethodInvocation` resolving to `ImagePicker.retrieveLostData` (library `package:image_picker`). If the result is assigned to a local variable `r`, look for any `r.files` or `r.exception` access within the same function body. If no `r.isEmpty` (or `!r.isEmpty`) check appears in a guard branch above those accesses, report on the first unguarded access.
- **Fix:** report-only. Inserting the guard requires knowing whether the intent is to return, throw, or continue.
- **False positives:** if the access is already inside a null-conditional chain (`r.files?.forEach(...)`) the immediate crash risk is reduced; consider suppressing or downgrading to INFO in that case.

---

### `image_picker_multi_result_unchecked_empty`

- **What/why:** `pickMultiImage` and `pickMultipleMedia` return `Future<List<XFile>>` — an empty list when the user cancels (the user canceling does NOT return null, it returns `[]`). Code that immediately calls `.first`, `[0]`, or `.last` on the result list without a length/emptiness check throws `RangeError: Index out of range` at runtime.
- **Detection (AST, type-safe):** match `MethodInvocation` whose name is `pickMultiImage` or `pickMultipleMedia` resolved to `package:image_picker`. If the `Future` result is `await`-ed into a local variable `files`, look for `files.first`, `files.last`, `files[0]` (or `files[<any literal>]`) in the same function body. If no `files.isNotEmpty`, `files.isEmpty`, or `files.length > 0` guard precedes those accesses, report on the unsafe access.
- **Fix:** mechanical — wrap the unsafe element access in `if (files.isNotEmpty) { … }`. Priority 80.
- **False positives:** if the access is inside a `.isNotEmpty ? files.first : fallback` ternary, or after `if (files.isEmpty) return;`, it is already guarded — skip.

---

## Implementation note

**New file:** `lib/src/rules/packages/image_picker_rules.dart`

**Register each rule class** in `lib/saropa_lints.dart` `_allRuleFactories` (one entry per class, e.g. `ImagePickerUncheckedNullResultRule.new`).

**Tier assignment** in `lib/src/tiers.dart`:
- ERROR-severity correctness rules (`image_picker_unchecked_null_result`, `image_picker_invalid_image_quality`, `image_picker_unawaited_pick`, `image_picker_multi_result_unchecked_empty`) → `recommendedOnlyRules`
- WARNING-severity rules (`image_picker_missing_retrieve_lost_data`, `image_picker_missing_image_quality`, `image_picker_camera_source_without_support_check`, `image_picker_lost_data_empty_check_missing`) → `professionalOnlyRules`
- INFO-severity rules (`image_picker_missing_max_dimensions`) → `comprehensiveOnlyRules`

**Migration / version gate:** No `>=` gate needed. `pickImage`/`pickVideo` are present and non-deprecated in 1.x; `getImage`/`getVideo` were removed in 1.0.0 so a `<` pre-upgrade gate would fire on nothing in the current codebase. The correctness and best-practice rules here apply to current 1.x usage as-is. Update [plans/plan_migration_plugin_system.md](plan_migration_plugin_system.md) to mark `image_picker` as "RF in progress".

**Not lint-able (runtime-only concerns):**
- Android process-death probability (depends on device memory pressure — not statically observable).
- Whether camera permission has been granted before calling `pickImage(source: ImageSource.camera)` (runtime state).
- Whether the picked `XFile.path` is still valid after the app resumes from background (file cache eviction — not statically observable).

---

## Sources

- [image_picker on pub.dev](https://pub.dev/packages/image_picker)
- [ImagePicker class API docs](https://pub.dev/documentation/image_picker/latest/image_picker/ImagePicker-class.html)
- [image_picker changelog](https://pub.dev/packages/image_picker/changelog)
- [retrieveLostData PlatformException issue #38025](https://github.com/flutter/flutter/issues/38025)
- [imageQuality crash on iOS 16+ issue #117670](https://github.com/flutter/flutter/issues/117670)
- [imageQuality / maxWidth clarification issue #82740](https://github.com/flutter/flutter/issues/82740)
- [image_picker camera not working on web issue #93770](https://github.com/flutter/flutter/issues/93770)
- [Android memory-pressure + retrieveLostData docs (flutter.googlesource.com README)](https://flutter.googlesource.com/mirrors/plugins/+/refs/tags/google_maps_flutter-v2.1.5/packages/image_picker/image_picker/README.md)
- [LeanCode image_picker best-practices guide](https://leancode.co/glossary/image-picker-in-flutter)
- [Medium: Flutter Image Picker with Optimisation](https://medium.com/@deepakgrandhi/flutter-image-picker-and-optimisation-55c485892994)

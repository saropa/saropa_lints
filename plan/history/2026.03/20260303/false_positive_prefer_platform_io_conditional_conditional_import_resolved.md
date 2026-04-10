# prefer_platform_io_conditional — false positive in conditionally imported files (RESOLVED)

**Rule:** `prefer_platform_io_conditional`  
**File:** `lib/src/rules/config/platform_rules.dart` — `PreferPlatformIoConditionalRule`  
**Status:** Resolved  
**Date:** 2026-03-03

## Resolution summary

The rule no longer reports in files that are the **native branch** of a conditional import (`import 'stub.dart' if (dart.library.io) 'native_impl.dart'` or `if (dart.library.ffi)`). Such files are never loaded on web, so requiring a `kIsWeb` guard inside them was a false positive.

**Implementation:** Added `lib/src/conditional_import_utils.dart` with `isNativeOnlyConditionalImportTarget(filePath)`. It lazily scans the project’s `lib/`, parses each file’s `ImportDirective.configurations`, and collects URIs guarded by `dart.library.io` or `dart.library.ffi`, resolved to absolute paths (relative and same-package `package:` URIs). Cached per project root. In `PreferPlatformIoConditionalRule.runWithReporter`, if the current file is a native-only target, the rule returns without registering the visitor.

**Tests:** `test/conditional_import_utils_test.dart` — null/empty path, no pubspec, io/ffi targets (relative and package URI), stub and non-target files return false.

**Fixture:** `example_platforms/lib/platform/prefer_platform_io_conditional_fixture.dart` — comment added that conditionally imported native-only files are out of scope (no report).

## References

- Original bug: was `bugs/false_positive_prefer_platform_io_conditional_conditional_import.md` (moved here after integration)
- Util: `lib/src/conditional_import_utils.dart`
- Tests: `test/conditional_import_utils_test.dart`, `test/platform_rules_test.dart`

---

## Original report (archived)

The rule flagged every `Platform.is*` use in files that are only imported when `dart.library.io` or `dart.library.ffi` is defined (e.g. `executor_native.dart`, `macos_platform_io.dart`), forcing global disable. Fix: conditional-import awareness so those files are skipped.

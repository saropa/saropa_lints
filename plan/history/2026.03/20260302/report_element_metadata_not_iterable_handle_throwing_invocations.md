# Bug: `handle_throwing_invocations` crashes analyzer plugin — `MetadataImpl` is not `Iterable`

**Status:** Fixed (2026-03-02)  
**Rule:** `handle_throwing_invocations` (`HandleThrowingInvocationsRule`)  
**Type:** Analyzer plugin crash (hard failure)  
**First observed:** 2026-03-02 (same root cause as AvoidDeprecatedUsageRule fix in 6.1.1)

**Fix:** `lib/src/rules/error_handling_rules.dart` — `_hasThrowsAnnotation` now uses `readElementAnnotationsFromMetadata(element.metadata)` from `lib/src/analyzer_metadata_compat_utils.dart` so metadata is read safely for both Iterable and MetadataImpl (analyzer 9+) shapes. No remaining `element.metadata as dynamic` iteration in lib/.

**Regression test:** `test/handle_throwing_invocations_metadata_crash_test.dart` — spawns temporary consumer projects, enables the rule, runs `dart analyze` on code with method invocations; asserts no plugin crash (exit 4) and no MetadataImpl/Iterable error. Includes false-positive guard (non-thrower and try/catch cases).

---

## Summary

On analyzer versions where `Element.metadata` is a wrapper (`MetadataImpl`) rather than an `Iterable`, the rule crashed in `_hasThrowsAnnotation` when doing:

- `for (final ann in element.metadata as dynamic) { ... }`

Error: `type 'MetadataImpl' is not a subtype of type 'Iterable<dynamic>'` (plugin exit code 4).

---

## Root cause

`HandleThrowingInvocationsRule._hasThrowsAnnotation` assumed `element.metadata` was directly iterable. Under analyzer 9+, metadata is a wrapper with an `.annotations` collection. The shared helper `readElementAnnotationsFromMetadata` already used by `AvoidDeprecatedUsageRule` was applied here.

---

## Verification

- `dart analyze lib/` passes
- `dart test test/handle_throwing_invocations_metadata_crash_test.dart` passes

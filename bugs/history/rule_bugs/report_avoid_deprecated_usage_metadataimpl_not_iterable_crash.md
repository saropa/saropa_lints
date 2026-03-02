# Bug: `avoid_deprecated_usage` crashes analyzer plugin — `MetadataImpl` is not `Iterable`

**Status:** Fixed (6.1.1)  
**Rule:** `avoid_deprecated_usage` (`AvoidDeprecatedUsageRule`)  
**Type:** Analyzer plugin crash (hard failure)  
**First observed:** 2026-03-02  

**Fix:** `lib/src/rules/code_quality_avoid_rules.dart` — tolerate analyzer metadata shape changes by reading annotations via analyzer’s `Metadata` wrapper (analyzer 9+) and falling back safely for older/unknown shapes; never iterate `element.metadata` as `dynamic Iterable`.

**Regression test:** `test/avoid_deprecated_usage_crash_test.dart` — spawns a temporary consumer project, enables the plugin, and runs `dart analyze`, asserting no plugin crash / exit code 4.

---

## Summary

Some analyzer versions expose `Element.metadata` as a wrapper object (e.g. `MetadataImpl`) rather than an `Iterable`. The rule previously attempted:

- `for (final ann in element.metadata as dynamic) { ... }`

which could throw:

- `type 'MetadataImpl' is not a subtype of type 'Iterable<dynamic>'`

This is a **hard failure** (plugin crash; `dart analyze` exit code 4).

---

## Root cause

`AvoidDeprecatedUsageRule._isDeprecated` assumed `element.metadata` was directly iterable. Under analyzer 9+, metadata is represented by a wrapper with an `.annotations` collection.

---

## Fix (implementation details)

**File:** `lib/src/rules/code_quality_avoid_rules.dart`

- Added a compatibility reader:
  - If `metadata is Metadata` → use `metadata.annotations`
  - If `metadata is Iterable` → filter to `ElementAnnotation`
  - Otherwise → return empty list (never crash)
- Added a small compatibility check for deprecation flags (`hasDeprecated`/`isDeprecated`) via `dynamic` access in try/catch.

If annotation extraction fails for any reason, the rule defaults to “not deprecated” and continues analysis.

---

## Verification

- `dart analyze` passes
- `dart test` includes `test/avoid_deprecated_usage_crash_test.dart` and passes


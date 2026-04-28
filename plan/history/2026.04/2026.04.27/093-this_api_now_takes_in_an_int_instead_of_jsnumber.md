# Plan #093 - prefer_int_for_jsarray_with_length

**Source:** Dart SDK 3.2.0 release notes (`dart:js_interop`)  
**Category:** Breaking-change migration  
**Priority:** Medium  
**Status:** Implemented

**Revision (2026-04-27):** The rule requires `JSArray` from `dart:js_interop` and a `JSNumber` length whose type resolves to that library, avoiding user-defined `JSArray` / `JSNumber` stubs.

---

## Normalized Requirement

In Dart 3.2 (`dart:js_interop`), `JSArray.withLength` parameter changed:

- **From:** `JSNumber`
- **To:** `int`

Authoritative source: Dart breaking changes entry for 3.2:
- "Changed `JSArray.withLength` to take `int` instead of `JSNumber`."

---

## Exact API Mapping

- **Symbol:** `JSArray.withLength`
- **Change:** constructor/factory length parameter `JSNumber` -> `int`

### Migration intent

Callers should pass Dart `int` lengths directly. Legacy `JSNumber` wrappers for
array-length construction are obsolete in 3.2+.

---

## Proposed Lint Rule

- **Rule name:** `prefer_int_for_jsarray_with_length`
- **Type:** migration
- **Severity:** `WARNING`
- **Impact:** `medium`
- **Autofix:** none initially

### Detection strategy

1. Match invocations of `JSArray.withLength(...)`.
2. Resolve symbol to `dart:js_interop` when possible.
3. Report argument patterns that remain JSNumber-centric (legacy wrappers or
   conversions) where plain `int` is now expected.

### False-positive guards

- Do not report user-defined `withLength` methods.
- Do not report already-correct `int` arguments.
- Avoid purely lexical matching when resolved symbol disagrees.

---

## Acceptance Criteria

- [x] Concrete symbol documented with source proof.
- [x] Rule only targets `JSArray.withLength` from `dart:js_interop`.
- [x] GOOD tests include valid `int` calls and same-name non-interop APIs.
- [x] No autofix unless a future pattern is guaranteed-safe.

---

## Implementation Checklist

- [x] Resolve exact symbol from SDK docs.
- [x] Rewrite plan with final mapping and rule scope.
- [x] Implement symbol-specific detector.
- [x] Add fixture/tests + registry/tier updates.
- [ ] Add changelog update (defer to release batching).

---

## Notes

- Keep coordinated with #091/#092; these are related but distinct API deltas.

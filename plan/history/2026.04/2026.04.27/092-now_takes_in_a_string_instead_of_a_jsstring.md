# Plan #092 - prefer_string_for_typeof_equals

**Source:** Dart SDK 3.2.0 release notes (`dart:js_interop`)  
**Category:** Breaking-change migration  
**Priority:** Medium  
**Status:** Implemented

**Revision (2026-04-27):** The rule requires a resolved `typeofEquals` from `dart:js_interop` and a `JSString` type that also resolves to that library, avoiding same-named user types.

---

## Normalized Requirement

In Dart 3.2 (`dart:js_interop`), `typeofEquals` parameter changed:

- **From:** `JSString`
- **To:** `String`

Authoritative source: Dart breaking changes entry for 3.2:
- "`typeofEquals` now takes `String` instead of `JSString`."

---

## Exact API Mapping

- **Symbol:** `typeofEquals`
- **Change:** parameter type `JSString` -> `String`
- **Related change:** return type also changed to `bool` (handled in #091 scope)

### Migration intent

Callers should pass Dart strings directly to `typeofEquals(...)` in 3.2+.
Legacy `JSString`-style argument construction/conversion should be removed.

---

## Proposed Lint Rule

- **Rule name:** `prefer_string_for_typeof_equals`
- **Type:** migration
- **Severity:** `WARNING`
- **Impact:** `medium`
- **Autofix:** none by default (argument normalization can be semantic)

### Detection strategy

1. Match `MethodInvocation` where `methodName == 'typeofEquals'`.
2. Confirm symbol resolves to `dart:js_interop` when available.
3. Report when first argument appears to be a `JSString`-typed value or legacy
   interop conversion pattern used only to satisfy pre-3.2 signature.

### False-positive guards

- Do not report non-interop methods named `typeofEquals`.
- Do not report when a plain Dart `String` argument is already used.
- Do not infer from lexical names alone if type resolution disagrees.

---

## Acceptance Criteria

- [x] Exact changed symbol documented with source proof.
- [x] Rule only targets `typeofEquals` from `dart:js_interop`.
- [x] GOOD tests include regular String callsites and same-name non-interop APIs.
- [x] Rule message points to String argument requirement.

---

## Implementation Checklist

- [x] Resolve exact API from SDK docs.
- [x] Rewrite plan with concrete symbol mapping.
- [x] Implement detector in Flutter SDK migration rules file.
- [x] Add fixture/tests and tier updates.
- [x] Validate rule scope with same-name user API fixture coverage.
- [ ] Add changelog update (defer to release batching).

---

## Notes

- Keep tightly scoped to `typeofEquals` argument migration.
- Coordinate with #091 return-type migration to avoid duplicate diagnostics.

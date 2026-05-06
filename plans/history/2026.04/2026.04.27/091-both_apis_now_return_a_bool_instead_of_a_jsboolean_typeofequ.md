# Plan #091 - avoid_legacy_jsboolean_return_assumptions

**Source:** Dart SDK 3.2.0 release notes (`dart:js_interop`)  
**Category:** Breaking-change migration  
**Priority:** Medium  
**Status:** Implemented

**Revision (2026-04-27):** The rule only matches `typeofEquals` / `instanceof` when the invoked member resolves to `dart:js_interop`, unwraps parenthesized / cast receivers before `.toDart`, and fixture `expect_lint` coverage uses a real `dart:js_interop` import so resolution matches the SDK.

---

## Normalized Requirement

In Dart 3.2 (`dart:js_interop`), these APIs changed return type:

1. `typeofEquals` : `JSBoolean` -> `bool`
2. `instanceof` : `JSBoolean` -> `bool`

Authoritative source: Dart breaking changes entry for 3.2:
- "Changed `typeofEquals` and `instanceof` APIs to both return bool instead of `JSBoolean`."

---

## Exact API Mapping

### Symbol table (Dart 3.1 -> 3.2)

- `typeofEquals(...)`
  - Old: returns `JSBoolean`
  - New: returns `bool`
- `instanceof(...)`
  - Old: returns `JSBoolean`
  - New: returns `bool`

### Scope intent

Flag usage patterns that still treat these calls as `JSBoolean` values in
post-3.2 code paths (for example chaining JSBoolean-specific conversions).

---

## Proposed Lint Rule

- **Rule name:** `avoid_legacy_jsboolean_return_assumptions`
- **Type:** migration / compatibility
- **Severity:** `WARNING`
- **Impact:** `medium`
- **Autofix:** none (semantic adaptation varies by callsite)

### Detection strategy

Detect callsites of `typeofEquals` / `instanceof` where surrounding code assumes
the result is a `JSBoolean` (for example, JSBoolean extension-only usage).

Recommended implementation shape:

1. Match `MethodInvocation` where `methodName` in `{typeofEquals, instanceof}`.
2. Resolve receiver/member to `dart:js_interop` when possible.
3. Report only when the result is used in a legacy-JSBoolean way; do not report
   plain boolean condition usage (`if (x.typeofEquals(...))` is already correct).

### Message guidance

Explain that these APIs already return Dart `bool` in 3.2+, so JSBoolean-era
adaptation should be removed and standard bool flow should be used.

---

## Acceptance Criteria

- [x] Exact changed members documented with source proof.
- [x] Lint only fires on `typeofEquals` / `instanceof` and only on legacy usage.
- [x] GOOD cases include normal bool usage in conditions/expressions.
- [x] No quick fix (semantic migration).

---

## Implementation Checklist

- [x] Resolve concrete symbols from SDK docs.
- [x] Rewrite plan with exact signatures and scope.
- [x] Implement detector in Flutter SDK migration rules file.
- [x] Add fixture BAD/GOOD coverage for legacy-JSBoolean assumptions.
- [x] Add metadata/registry/tier updates.
- [x] Add changelog update.

---

## Notes

- Keep this rule focused on return-type migration behavior only.
- Coordinate with #092 and #093 to avoid duplicate reports on the same line.

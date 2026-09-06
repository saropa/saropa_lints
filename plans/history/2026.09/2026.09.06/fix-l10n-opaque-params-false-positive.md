# Fix: l10n diagnostic false positive on variable params

The `saropa-l10n` diagnostic provider reported "expects params but none passed" on `l10n()` calls
where the second argument was a variable reference or expression (e.g. `params`, `band.params`,
`getParams()`) instead of an inline object literal. The `extractParamsBlock` parser only recognized
`{` as the start of a params argument, returning `undefined` for any other token after the comma.

## Root Cause

`extractParamsBlock` in `l10nParsers.ts` scanned past the comma separator and checked whether the
next non-whitespace character was `{`. Any other character — including valid identifier starts —
returned `undefined`, which the diagnostic code in `l10nDiagnostics.ts` treated as "no params
passed at all."

## Fix

Added an `OPAQUE_PARAMS` sentinel to `l10nParsers.ts`. `extractParamsBlock` now:
- Returns `OPAQUE_PARAMS` when the token after the comma is an identifier (but not `undefined` or
  `null`, which are functionally "no params").
- Returns `undefined` for `undefined`/`null` keywords so the "expects params but none passed"
  diagnostic still fires correctly for those cases.
- Extracted the brace-matching loop into a shared `extractBalancedBrace` function to deduplicate
  the balanced-brace parsing logic.

The diagnostic code skips static key extraction when the params block is opaque — no false positive,
no false negative.

A variable-resolution approach (tracing `const name = {...}` declarations backward from the call
site) was prototyped and rejected after code review: naive backward-text search without scope
awareness can match the wrong declaration (e.g. a same-named variable in a different function),
and wrong resolution produces worse outcomes than skipping. Scope-aware resolution would require
a full TypeScript AST, which is out of scope for this regex-based diagnostic provider.

## Files Changed

- `extension/src/i18n/l10nParsers.ts` — added `OPAQUE_PARAMS` export, `extractBalancedBrace`
  shared helper, updated `extractParamsBlock` to handle variable references and
  `undefined`/`null` keywords.
- `extension/src/i18n/l10nDiagnostics.ts` — imported `OPAQUE_PARAMS`, added early-return when
  `paramsBlock === OPAQUE_PARAMS`.
- `extension/src/test/l10nParsers.test.ts` — seven new test cases: variable reference, property
  access, function call, ternary, `undefined`, `null`, spread-into-object.

## Hardening (2026-09-06)

- Introduced a branded `OpaqueParams` type using a unique-symbol brand. The type prevents
  accidental creation of sentinel values from plain strings (requires explicit cast) and makes
  the three-state return type of `extractParamsBlock` self-documenting:
  `string | OpaqueParams | undefined`.
- Extracted `extractBalancedBrace` as a shared export with 8 dedicated unit tests, eliminating
  the duplicated brace-depth loop that previously existed inside `extractParamsBlock`.
- Fixed `extractParamsBlock` accepting `undefined` and `null` keywords as opaque params —
  they now correctly return `undefined` so the "expects params but none passed" diagnostic fires.
- Variable-resolution approach (tracing `const name = {...}` declarations backward) was
  prototyped, code-reviewed by 8 parallel review angles, and rejected: naive backward text
  search without scope awareness can match the wrong declaration (same-named variable in a
  different function), producing worse outcomes than skipping. Scope-aware resolution would
  require a full TypeScript AST.

## Finish Report (2026-09-06)

Verified: 49/49 parser tests pass (15 new since the original fix). TypeScript compiles cleanly
under both `tsconfig.json` and `tsconfig.test.json`. The false positive on `orphanPreflight.ts:64`
and `memoryPressureWatcher.ts:491` (both pass params via variables) is eliminated.
`l10n('key', undefined)` correctly triggers the "expects params but none passed" diagnostic.
No user-facing strings changed.

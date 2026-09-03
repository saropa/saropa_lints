# l10n Diagnostic Provider — Test Exclusion, Extra-Params, Ignore Directive, Dead Keys

## Problem

The `saropa-l10n` diagnostic provider scanned `l10nParsers.test.ts`, whose string literal test fixtures contain synthetic `l10n('key', ...)` patterns indistinguishable from real calls, producing false-positive "key not defined" warnings.

## Changes

1. **Targeted test exclusion** — early-return guard skips only `l10nParsers.test.ts` (with `path.sep` prefix). Three other test files using real l10n keys remain validated.
2. **Extra-params detection** — Hint-severity diagnostic when code passes params the en.json template doesn't reference. No-placeholder early-exit restructured so the check covers all keys.
3. **`// l10n-ignore-next-line` directive** — comment directive suppresses all diagnostics for the next `l10n()` call. Validates the directive appears inside `//` or `/*` context, picking whichever marker appears first.
4. **Dead-key detection** — scans all TypeScript source files and reports unreferenced en.json keys as Hint diagnostics. Position-finding uses cascading segment search with `:` guard to disambiguate 161 duplicate leaf names and avoid false-matching JSON string values.
5. **Quick-fix (single + bulk)** — code action removes a dead key from all 25 locale files with trailing-comma fixup. Bulk command (`saropaLints.l10n.removeAllDeadKeys`) removes all dead keys at once with modal confirmation, processing in reverse document order to avoid position shifts.

## Finish Report (2026-09-03)

**Defect:** False-positive "key not defined in en.json" warnings on `l10nParsers.test.ts`.

**Fix:** Five features across `l10nDiagnostics.ts` (modified), `l10nDeadKeys.ts` (new), and `extension.ts` (import + registration). Dead-key scan runs on en.json changes and activation (not on .ts saves). Quick-fix guards against only-entry objects and uses `trimEnd().endsWith(',')` for comma detection.

**Files:** `extension/src/i18n/l10nDiagnostics.ts`, `extension/src/i18n/l10nDeadKeys.ts` (new), `extension/src/extension.ts`, `CHANGELOG.md`.

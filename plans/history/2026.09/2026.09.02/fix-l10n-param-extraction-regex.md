# Fix: l10n diagnostic param-extraction regex

The `saropa-l10n` diagnostic provider (`l10nDiagnostics.ts`) reported false "missing params" warnings on every multi-param `l10n()` call — e.g. `l10n('key', { count, size })` flagged `size` as missing. Three call sites were affected across `extension.ts`, `cleanupCommand.ts`, and `processMonitor.ts`.

## Root Cause

`OBJ_KEY_RE` (`/(?:^|[{,])\s*(?!\.\.\.)(\w+)\s*(?::|[,}])/g`) consumed the trailing `,` or `}` as a literal match. When the regex engine advanced `lastIndex` past that delimiter, the next key's leading `(?:^|[{,])` could not match because the required `,` was already consumed. Only the first key in each params object was detected.

A secondary false positive arose from the inline code comment on line 21 containing a literal `l10n('dotted.key')` example, which the scanner's own `L10N_RE` matched as a real call.

## Fix

Replaced `OBJ_KEY_RE` regex entirely with `extractTopLevelKeys()` — a state-machine parser that walks the params object character-by-character, tracking nesting depth for `{}`, `()`, `[]` and skipping string literals. At depth 0 it identifies identifier tokens followed by `:` (explicit key), `,` or `}` (shorthand property). Spread syntax (`...operand`) is consumed without adding the operand as a key.

Also added `blankComments()` — replaces comment contents with spaces (preserving string length for position mapping) before running `L10N_RE`, so `l10n()` examples in code comments no longer produce false "undefined key" diagnostics.

Extracted `skipStringLiteral()` as a shared helper used by `blankComments`, `extractParamsBlock`, and `extractTopLevelKeys`, eliminating three duplicated inline string-skip loops.

Updated spread handling in `extractTopLevelKeys` to consume member-access dots (`...obj.nested.path`) so dotted spread operands aren't misidentified as keys.

## Finish Report (2026-09-02)

- **Changed file:** `extension/src/i18n/l10nDiagnostics.ts` — replaced `OBJ_KEY_RE` regex with `extractTopLevelKeys()` state-machine; added `blankComments()` for comment-aware scanning; extracted `skipStringLiteral()` shared helper; improved spread-operand consumption.
- **CHANGELOG:** Entry added under Maintenance in `[15.2.9] — Unreleased`.
- **Tests:** No existing test harness for `l10nDiagnostics.ts`. Verification is via the diagnostics clearing on extension reload.
- **en.json:** No changes — the catalog already had correct `{placeholder}` tokens.
- **TypeScript compilation:** Clean (`npx tsc --noEmit` exits 0).

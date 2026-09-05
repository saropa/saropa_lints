# commandCatalogRegistry.test.ts pre-existing failure

## Status: Open

## Summary

`npm test` in `extension/` fails on `commandCatalogRegistry.test.ts` with an
assertion mismatch: the expected command list includes Package Vibrancy commands
(`saropaLints.packageVibrancy.*`) that are no longer registered, producing an
empty-array diff against the expected array.

## Reproduction

```powershell
cd d:\src\saropa_lints\extension
npm test
```

The failure is in `out-test\test\commandCatalogRegistry.test.js:139` — the
expected commands array no longer matches the actual registered commands.

## Impact

- Does not block individual test suites (scoped `npx mocha` runs pass).
- Blocks `npm test` (full suite).
- Pre-existing as of 2026-09-05; not introduced by any recent change.

## Likely cause

Command registrations were removed or renamed without updating the expected
catalog in the test fixture.

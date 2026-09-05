# commandCatalogRegistry.test.ts pre-existing failure

## Status: Fixed

## Summary

`npm test` in `extension/` failed on `commandCatalogRegistry.test.ts` with two
classes of assertion mismatch:

1. **17 commands in package.json had no catalog entry** — commands added to the
   manifest without a matching entry in the command catalog registry.
2. **15 palette-hidden commands were not marked `internal`** — commands with
   `when: false` in the `commandPalette` menu but missing `internal: true` in
   their catalog entry.

## Fix

- Added 17 missing catalog entries across
  `commandCatalogEntriesProject.ts` (16) and
  `commandCatalogEntriesVibrancy.ts` (1: `showOpportunities`).
- Marked 15 palette-hidden commands as `internal: true` in
  `commandCatalogEntriesVibrancy.ts`.

All 17 tests in `commandCatalogRegistry.test.ts` now pass.

## Commands added to catalog

`auditFolder`, `createBaseline`, `enableRule` (internal), `findStaleIgnores`,
`fixStaleIgnores`, `fullAudit`, `killOrphanedDaemons`, `lspServer.start`,
`lspServer.stop`, `lspServer.restart`, `migrateConfig`,
`openAnalysisOptimizer`, `openFinding` (internal), `setLane`,
`showProcessHealth`, `toggleDebugPanel`,
`packageVibrancy.showOpportunities`.

## Commands marked internal

`suppressPackageByName`, `suppressByCategory`, `focusDetails`,
`filterBySeverity`, `filterByProblemType`, `filterByCategory`,
`filterBySection`, `sortDependencies`, `toggleCodeLens`,
`updateAllMajor`, `updateAllMinor`, `updateAllPatch`,
`logAllDetails`, `addRegistryAuth`, `removeRegistryAuth`.

## Finish Report (2026-09-05)

The command catalog registry test suite (`commandCatalogRegistry.test.ts`) failed
on two sync assertions: 17 commands declared in `package.json` had no matching
entry in the catalog data files, and 15 commands hidden from the command palette
via `when: false` lacked the `internal: true` marker the audit test requires.

Root cause: commands were added to `package.json` (and their palette visibility
configured in `contributes.menus.commandPalette`) without corresponding updates
to the catalog entry arrays in `commandCatalogEntriesProject.ts` or
`commandCatalogEntriesVibrancy.ts`.

**Changes:**

- `commandCatalogEntriesProject.ts` — 16 new `CatalogEntry` objects added,
  categorized under Setup & Configuration (3), Analysis (12), Rules & Fixes (1),
  and Violations & Filtering (1). Two entries (`enableRule`, `openFinding`)
  marked `internal: true` matching their `when: false` palette status.
- `commandCatalogEntriesVibrancy.ts` — 1 new entry
  (`packageVibrancy.showOpportunities`); 15 existing entries gained
  `internal: true` to match their `when: false` palette declarations.
- `CHANGELOG.md` — Internal bullet added.

**Verification:** `npx tsc --noEmit -p .`, `npx tsc -p tsconfig.test.json`,
and `npx mocha out-test/test/commandCatalogRegistry.test.js` — 17/17 pass.
No code-review findings at medium level.

**Hardening (post-review):**

- Moved `toggleDebugPanel` from "Analysis" to "Views & Navigation" — it opens
  a UI panel, not an analysis action.
- Changed `killOrphanedDaemons` icon from `trash` (implies data deletion) to
  `debug-disconnect` (process termination).

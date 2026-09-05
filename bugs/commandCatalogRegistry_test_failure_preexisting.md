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

# Fix sidebar stale-ignores UX: label, concurrency, and ENOENT

The "Fix stale ignores" sidebar action had three defects: the label was too long for narrow sidebar widths, double-clicking launched concurrent CLI processes, and projects without a prior scan crashed with ENOENT because `reports/.saropa_lints/` did not exist.

## Finish Report (2026-09-06)

### Defects addressed

1. **Label length** — "Fix stale ignores" renamed to "Prune ignores"; "Initialize / Update config" shortened to "Update config" with descriptions carrying the shed detail.
2. **No concurrency guard** — All four stale-ignore entry points use a shared `createBusyGuard` utility extracted to `commandGuards.ts`. Blocked clicks show a brief status-bar message instead of silently no-oping.
3. **ENOENT on first run** — `fs.mkdirSync(dir, { recursive: true })` centralized in `runFindScan` (the shared function that writes the JSON output path), rather than duplicated at each call site.

### Code-review findings applied

- **Dynamic `await import('node:fs')` x4** replaced with a single static import at the top of the file, matching the existing `crypto` and `path` imports.
- **Silent busy guard** now emits `l10n('staleIgnores.info.alreadyRunning')` via `setStatusBarMessage`, satisfying the project's "no silent async" rule.
- **mkdirSync duplication** consolidated from 3 call sites into `runFindScan`.
- **Hardcoded English sidebar labels** ("Run analysis", "Update config") routed through `l10n()` with new `sidebar.actions.*` keys in `en.json`.
- **Busy guard duplication** — extracted `createBusyGuard` to `commandGuards.ts`, a reusable concurrency guard that tracks busy state and shows visible feedback. All four stale-ignore commands now delegate to it. 5 unit tests added in `commandGuards.test.ts`.

### Audit of other sidebar actions

| Sidebar item | Concurrency | ENOENT risk |
|---|---|---|
| Run analysis | Already has superseding CTS (`setup.ts:1524`) | N/A — Dart CLI manages dirs |
| Prune ignores | **Fixed** | **Fixed** |
| Update config | Progress notification provides implicit serialization | N/A — writes config files, not reports dir |

### Not in scope

- `cross-file-commands.ts` (graph, report, snapshot) also uses `saropaLintsDataPath` without `mkdirSync` — command-palette only, not sidebar; same ENOENT risk on first-ever run.
- Codebase-wide `ensureDirSync` utility for the remaining 15+ mkdirSync call sites — separate infrastructure task.

### Files changed

- `extension/src/commandGuards.ts` — NEW: reusable `createBusyGuard` utility
- `extension/src/stale-ignore-commands.ts` — static fs import, uses `withBusyGuard`, centralized mkdirSync in `runFindScan`
- `extension/src/views/sectionedSidebar.ts` — shortened labels, l10n routing
- `extension/src/i18n/locales/en.json` — renamed `fixLabel`/`fixDescription`, added `alreadyRunning` + `sidebar.actions.*` keys
- `extension/src/test/commandGuards.test.ts` — NEW: 5 unit tests for the busy guard
- `extension/src/test/views/overviewTreeFlat.test.ts` — updated comment text to match new labels
- `extension/tsconfig.test.json` — added new files to test include list
- `CHANGELOG.md` — unreleased section for 16.0.0-beta.8

# Severity Filter Sidebar Toggles

The VS Code extension lacked a way to bulk-suppress diagnostic severities. Users with large projects saw 13,000+ hint-level diagnostics flood the Problems panel with no quick way to dismiss an entire severity class.

## Finish Report (2026-08-16)

### Problem
Projects with thousands of lint rules at the `comprehensive` or `pedantic` tier generated overwhelming diagnostic counts. The only existing severity filtering was session-scoped (Quick Pick) or workspace-state (suppressions store) — neither discoverable nor persistent across reloads without manual action.

### Solution
Four boolean VS Code settings (`saropaLints.severity.error`, `.warning`, `.info`, `.hint`) filter diagnostics at the `DiagnosticCollection.set()` boundary — before they reach the Problems panel. All default to `true`. A dedicated "Severity Filters" sidebar section provides one-click toggles.

### Files changed

| File | Change |
|------|--------|
| `extension/src/config/severityConfig.ts` | NEW — reads severity toggle settings, exports `getEnabledSeverities()`, `isSeverityEnabled()`, `affectsSeveritySettings()`, `getEnabledSeverityStrings()` |
| `extension/src/scanOnSave/scanOnSaveController.ts` | `_applyDiagnostics` caches raw results in `_lastDiagnosticsByFile` and filters via `getEnabledSeverities()`; new `_refilterDiagnostics()` re-filters cached results on severity toggle change without rescanning; `_publishFiltered()` reads the enabled set once per batch |
| `extension/src/vibrancy/providers/diagnostics.ts` | Filters vibrancy diagnostics via `getEnabledSeverities()` before `_collection.set()` |
| `extension/src/views/issuesTree.ts` | Initializes `severitiesToShow` from settings; watches config changes; `clearFilters()` resets to settings-based defaults; added `dispose()` |
| `extension/src/views/configTree.ts` | Removed severity rows from Settings section (moved to own sidebar section) |
| `extension/src/views/sectionedSidebar.ts` | New `severityFilters` view ID; `buildSeverityFilterItems()` builder; new `FlatSectionProvider` |
| `extension/src/extension.ts` | `registerSeverityToggle()` helper; 4 toggle command registrations |
| `extension/package.json` | 4 settings in "Severity Filters" config section; `saropaLints.severityFilters` view; 4 toggle commands; test glob |
| `extension/package.nls.json` | Section title, 4 setting descriptions, view name, 4 command titles |
| `extension/src/test/config/severityConfig.test.ts` | NEW — 7 unit tests for severity config reader |
| `extension/tsconfig.test.json` | Added `severityConfig.ts` and its test to the include list |
| `CHANGELOG.md` | `### Added (Extension)` entry |

### Key design decisions
- **Filter extension-side, not CLI-side.** The scan CLI supports `--min-severity` but that requires CLI params the user cannot discover or persist from the UI. VS Code settings survive workspace reloads and `init --tier` re-runs (which only write `analysis_options.yaml`).
- **Cache + re-filter, not clear + rescan.** On severity toggle change, `_refilterDiagnostics()` re-applies the filter to cached raw results. A clear + rescan approach fails because `_pendingFiles` is empty when no save has occurred, causing `_runQueuedScan` to no-op and leaving the Problems panel blank.
- **Batch `getEnabledSeverities()` instead of per-diagnostic `isSeverityEnabled()`.** The enabled set is read once per `_publishFiltered` / vibrancy `update()` call, not per diagnostic — avoids thousands of redundant `getConfiguration()` calls.
- **Own sidebar section.** The 4 severity toggles live in a dedicated "Severity Filters" collapsible panel, not mixed into the existing Settings section.

### Known limitations
- Vibrancy diagnostics filter at `update()` time (next pubspec evaluation), not instantly on toggle change — no config watcher forces vibrancy re-evaluation.
- Sidebar `LeafItem` labels are hardcoded English, matching the existing pre-i18n pattern for all sidebar settings rows.
- The 4 toggle commands are not yet in `commandCatalogEntriesProject.ts` (the "Show All Commands" catalog).

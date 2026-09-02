# Shedding Webview Integration

The Config Dashboard (Manage Rule Packs) had no visibility into which rules were temporarily disabled by the memory pressure handler. Users could only see shedding state via the status bar tooltip — a single summary line with no per-rule detail.

This change surfaces the full shedding breakdown inside the Config Dashboard, making shed rules visible, clickable, and grouped by shed category.

## Finish Report (2026-09-01)

### Changes

**`extension/src/rulePacks/rulePacksWebviewProvider.ts`**
- Added `_memoryPressureState` field and `setMemoryPressureState()` setter to receive pressure updates from the watcher.
- Extended `DashboardContext` with `shedByCategory` (category → rule names map), `shedCategoryTotals` (category → total count), `shedRuleCount`, and `shedRuleNames` (flat Set for O(1) lookup).
- `_collectDashboardContext()` populates shed data from the pressure state, including totals that may exceed the capped arrays.
- `_buildShedRulesSection()` renders a collapsible `<details>` section listing shed rules grouped by category (type-resolving, high-cost, INFO severity, WARNING severity), with a "+N more" overflow hint when the array is capped at 20.
- `_buildPackRow()` now accepts a `shedRuleNames` set and marks shed rules with a `.shed` CSS class and a "shed" badge in expanded pack detail rows.
- Threading: `shedRuleNames` passed through `_buildPackTable` → `_buildPackDomainGroups` → `_buildPackDomainGroup` → `_buildPackRow`.

**`extension/src/extension.ts`**
- `memoryWatcher.onStateChange` callback now pushes state to `rulePacksWebviewProvider.setMemoryPressureState()`, triggering a panel refresh.

**`extension/src/rulePacks/configDashboardStyles.ts`**
- Added `shedRulesStyles()`: amber-accented group headings (using `--vscode-editorWarning-foreground`), dimmed rule links in shed rows and pack detail badges, and a compact `.shed-badge` inline indicator.

**`extension/src/i18n/locales/en.json`**
- Added `memoryPressure.dashboard.*` keys: `shedSectionTitle`, `shedHint`, `shedBadge`, `shedBadgeTooltip`, `categoryTypeResolving`, `categoryHighCost`, `categoryInfoSeverity`, `categoryWarningSeverity`, `moreRules`.

- `_runDashboardCommand()` handles a new `restartAnalyzer` id that calls `dart.restartAnalysisServer` — clears memory pressure by restarting the analysis server. Button renders in the shed section hint paragraph.

### Known Limitations

- **20-rule cap per category**: `getShedDetails()` on the Dart side caps rule name arrays at 20. The dashboard shows the correct total and a "+N more" overflow hint, but per-rule badges in pack rows are only applied to the first 20 listed names. Lifting the cap requires a Dart-side change.
- **Locale catalogs not regenerated**: New `en.json` keys need `generate_translations.py` run before shipping to non-English locales.
- **Pre-existing: tooltip category labels not localized**: `memoryPressureTooltipLine()` in `memoryPressureWatcher.ts` uses hardcoded English strings for category names in the status bar tooltip. Separate fix needed.

### Verification

1. TypeScript compilation: `npx tsc --noEmit` passes cleanly.
2. No existing test breakage — the test file covers exported utility functions, not the changed private methods.
3. Manual verification requires triggering memory pressure in a real VS Code session (Phase 4 test from the handover).

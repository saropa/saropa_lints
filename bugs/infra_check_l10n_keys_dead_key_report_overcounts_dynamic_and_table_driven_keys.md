# BUG: `check_l10n_keys.py` — dead-key report overcounts: 260 of 392 "unreferenced" keys are live (dynamic or table-driven)

**Status: Fix Ready**

<!-- Checker fix applied. Remaining work: delete the 132 truly dead keys (list below) from en.json and all 24 locale files. -->

Created: 2026-09-19
Rule: n/a (infrastructure — `extension/scripts/check_l10n_keys.py`)
File: `extension/scripts/check_l10n_keys.py` (dead-key report, `main()`; new detectors `_collect_extra_refs`, `_prefix_const_refs`, `_DYNAMIC_FAMILIES`)
Severity: False positive (warning noise) / risk of wrongly deleting live keys
Rule version: n/a

---

## Summary

`python3 extension/scripts/check_l10n_keys.py` warned that keys in `en.json` were "defined but never referenced in code" (389 at filing, 392 at verification time because en.json kept growing). Verified: **260 of 392 (66%) are live** and were invisible only because the checker matched nothing but a literal `l10n('a.b')` call. Only **132 are truly dead**. After the fix the warning lists exactly those 132; exit code stays 0 and no false "missing" errors appear (`All 1795 l10n keys resolve`, also with `--check-params`).

---

## Attribution Evidence

The checker's only reference detectors were `_L10N_RE` (literal `l10n('key')`) and `*Key` string-union type aliases. Everything below was verified by grepping `extension/src` (non-test TS), `extension/package.json` and `package.nls.json`; no key was found referenced from the manifest or non-TS files.

---

## Reproducer

```text
python3 extension/scripts/check_l10n_keys.py
⚠ 392 key(s) defined in en.json but never referenced in code:   (before fix)
⚠ 132 key(s) defined in en.json but never referenced in code:   (after fix)
```

---

## Expected vs Actual

- **Expected:** the report lists only keys with no reference anywhere.
- **Actual (before fix):** 260 live keys reported as dead; deleting them per the warning would have broken toolbar, column, flag, pack and engine UI.

---

## Confirmed Root Cause

Classification of the 392 keys reported before the fix:

| Class | Count | Mechanism |
|---|---|---|
| DYNAMIC-USED (key built at runtime from an id) | 110 | see table below |
| LITERAL-BUT-MISSED-BY-SCRIPT — plain dotted string literal equal to the key, not inside `l10n('...')` | 88 | e.g. `titleKey`-style/data properties and helper-wrapper args: `projectMap.reports.*` (`views/projectMapReports.ts`), `packageDashboard.tabs.*` (`vibrancy/views/packages-tabs.ts`), `packageDashboard.settingsTab.*` (`vibrancy/views/settings-tab.ts`), `statusBar.menu.*` (`statusBarLabel.ts`), `machineDashboard.group.*`, `memoryPressure.statusBar/tooltip/dashboard.*`, `rulesTiers.tab/configFile.*`, `featureInventory.controls/feature/package.*`, `packageDetail.version.*`, `debug.ci.publish.*`, `systemHealth.tooltip.*` |
| LITERAL-BUT-MISSED-BY-SCRIPT — key assembled from a file-local prefix constant, e.g. `const tb = 'packageDashboard.toolbar'; l10n(\`${tb}.rescanLabel\`)` | 62 | `packageDashboard.toolbar.*` (43, `vibrancy/views/report-html-top.ts:451`), `commandCatalog.script.*` (12, `views/commandCatalogWebviewHtml.ts:47`, `const s`), `commandCatalog.search.*` (7, same file line 66) |
| TRULY DEAD | 132 | list below |

Dynamic families (all now allowlisted with the mechanism re-verified on every run):

| Family | Keys | Mechanism |
|---|---|---|
| `packageDashboard.columns.<id>.<label\|tooltip>` | 38 | `vibrancy/views/report-html-table.ts:27` `col(cid, part)` |
| `codeHealth.flag.<k>.<label\|evidence\|rule>` | 24 | `views/projectVibrancyClientScript.ts:39-41` (serialised into the webview) |
| `stylistic.desc.<pack.id>` | 12 | `rulePacks/rulePacksWebviewProvider.ts:1710` |
| `packs.domainDesc.<slug>` | 9 | `rulePacks/rulePacksWebviewProvider.ts:1323` |
| `debug.engine.statusValue.<status>` | 8 | `systemHealth/engineCardsHtml.ts:99`, `views/sectionedSidebar.ts:853` |
| `packageDashboard.summary.<key>Title` | 6 | `vibrancy/views/report-html-top.ts:254` |
| `featureInventory.category.<c>` | 5 | `vibrancy/views/feature-inventory-utils.ts:47` |
| `debug.engine.description.<k>` | 4 | `systemHealth/engineCardsHtml.ts:82` |
| `analysisOptimizer.priority.<p>` | 3 | `analysisOptimizer/analysisOptimizerWebviewProvider.ts:539` |
| `featureInventory.chip.<state>` | 1 | `vibrancy/views/feature-inventory-utils.ts:52` |

Hypothesis A (string-built keys) and the table-driven part of B confirmed. Webview script keys (`codeHealth.flag.*`, `commandCatalog.script.*`) are live. Hypothesis C confirmed too, but the dead set is 132, not "the remainder after A/B" in the sense originally feared: several families the filing suspected (`findingsDash.script.*`, `codeHealth.script.*`, `memoryPressure.*`, `toolbar.*`, `empty.*`, `loading.*`) are only PARTLY dead; per key, see the list.

---

## Suggested Fix

Done in the checker (see Changes Made). Follow-up: delete the truly dead keys below from `en.json` and all 24 locale files. That touches every locale file, so it should be done by whoever owns the translation pipeline (the i18n sync/coverage tooling under `extension/scripts/i18n/`), in one commit with the locale parity test run afterwards, not by hand. Caveat for the 39 keys in the `views/webview-strings.ts` groups (`a11y`, `empty`, `error`, `filter`, `loading`, `offline`, `stale`): that file holds hard-coded English copies of the same strings and never calls `l10n()`. They are dead today, but deleting them may be wrong if that table is meant to be migrated to l10n; decide that first. Some keys also appear in `extension/scripts/i18n/english_allowed.json` (an allowlist) which should be pruned together.

---

## Changes Made

- `extension/scripts/check_l10n_keys.py`: dead-key warning now also counts (1) any dotted-key-shaped string literal in non-test TS that exactly equals an en.json key, (2) file-local prefix constants resolved through `${NAME}.rest` and `NAME + '.rest'` (tries every prefix when a name such as `s` is reused), (3) an explicit `_DYNAMIC_FAMILIES` allowlist of 10 documented families, each with a suffix regex and a mechanism regex that is re-checked against the source file on every run (a removed mechanism silently un-allowlists its keys). None of these feed the "missing from en.json" check, so no new false errors. Exit code still 0; also 0 with `--check-params`.
- `extension/scripts/test_check_l10n_keys.py` (new): 5 unit tests for the prefix-const resolver and dotted-literal regex (`python3 -m unittest extension/scripts/test_check_l10n_keys.py`).
- Result: 392 -> 132 reported.
- Not done: no keys deleted; no locale, CHANGELOG or commit changes.

Residual limitation: the literal detector counts a key referenced from a dead code path as live, and the family allowlist trusts the runtime id set to cover the keys.

---

## Truly Dead Keys (132) — delete in follow-up

```text
a11y.announcer
a11y.collapseRow
a11y.copyRow
a11y.keyboardShortcuts
a11y.selectAll
a11y.sortBy
brand.prefix
codeHealth.gauge.ariaLabel
codeHealth.gauge.tooltip
codeHealth.scanningTitle
codeHealth.script.flagChip
codeHealth.script.removeAria
codeHealth.script.rowsVisible
codeHealth.script.searchChip
codeHealth.table.colGrade
codeHealth.table.hint
codeHealth.table.topCount
commandCatalog.status.categories
commandCatalog.status.commands
commandCatalog.status.recent
consolidated.empty
consolidated.evidence.advisor
consolidated.evidence.logCapture
consolidated.fetching
consolidated.gradeExcellent
consolidated.gradeFair
consolidated.gradeGood
consolidated.gradeSevere
consolidated.gradeWeak
consolidated.kicker
consolidated.liveTitle
consolidated.more
consolidated.noOccurrences
consolidated.searchPlaceholder
consolidated.summaryFindings
consolidated.summaryRules
consolidated.wordErrors
consolidated.wordFiles
consolidated.wordInfo
consolidated.wordWarnings
dashboards.controls.analyzerPlugin
dashboards.controls.analyzerPluginAbsent
dashboards.controls.analyzerPluginDisabled
debug.ci.enabled
debug.engine.status
debug.panel.title
empty.noDataCta
empty.noDataMessage
empty.noDataTitle
empty.noFindingsCta
empty.noFindingsMessage
empty.noFindingsTitle
empty.noMatchCta
empty.noMatchMessage
empty.noMatchTitle
empty.noProjectCta
empty.noProjectMessage
empty.noProjectTitle
error.copyDetails
error.genericTitle
error.partialRetry
error.partialSummary
error.reload
error.retry
error.unreachable
filter.clearSearch
filter.recentLabel
filter.searchPlaceholder
findingsDash.audit.canceledLabel
findingsDash.audit.completedLabel
findingsDash.audit.failedLabel
findingsDash.charts.impactMix
findingsDash.chip.impactOff
findingsDash.chip.removeFilterAria
findingsDash.hero.productTitle
findingsDash.menuPalette.reEnableNoneTitle
findingsDash.script.analysisComplete
findingsDash.script.analysisFailedDetail
findingsDash.script.analysisRunning
findingsDash.script.analysisStartedDetail
findingsDash.script.announceImpacts
findingsDash.script.announceSearch
findingsDash.script.announceSeverities
findingsDash.script.bulkSelected
findingsDash.script.metaDone
findingsDash.script.metaRunning
findingsDash.seg.toggleImpactTitle
findingsDash.status.lastRunPrefix
findingsDash.supplementary.analyzerTodosOn
findingsDash.supplementary.analyzerTodosPromo
findingsDash.supplementary.otherAnalyzerOn
findingsDash.supplementary.otherAnalyzerPromo
findingsDash.supplementary.tooltipLive
findingsDash.suppressions.unknownKind
findingsDash.toolbar.impactGroupAria
findingsDash.toolbar.impactLabel
findingsDash.toolbar.refreshViolationsTitle
loading.cancel
loading.checking
loading.fetching
loading.preparing
loading.scanning
loading.thinking
loading.working
machineDashboard.heapCap.prompt
memoryPressure.tooltip.shedLevel0
notify.misc.actionDismiss
offline.banner
offline.cachedFooter
offline.reconnecting
opportunities.report.noWorkspace
packageDashboard.deps.sharedBadge
packageDashboard.deps.transitiveDepsHeading
packageDashboard.detail.fixInVersion
packageDashboard.detail.vulnerabilitiesHeading
packageDashboard.links.changelog
packageDashboard.links.heading
packageDashboard.links.issues
packageDashboard.links.pubDev
packageDashboard.links.repository
packageDashboard.links.versions
packageDashboard.references.andMore
packageDashboard.references.fileReferencesHeading
packageDashboard.references.reExportSuffix
packageDashboard.references.searchImports
stale.statusPill
status.health.lastRunTooltip
systemHealth.command.killOrphans
toolbar.refresh
toolbar.rescan
toolbar.resetView
wideReport.noReportYet
```

---

## Fixture Gap

Partly closed: unit tests cover the new detectors. There is still no end-to-end fixture tree running the whole script.

---

## Environment

- Script: `extension/scripts/check_l10n_keys.py`; verified 2026-09-19 against 2194 en.json leaf keys

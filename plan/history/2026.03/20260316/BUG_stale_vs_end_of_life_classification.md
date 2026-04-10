# BUG: Low-Score Packages Incorrectly Labeled "End of Life"

**Status:** RESOLVED
**Date:** 2026-03-16
**Severity:** High — misleading classification for users

## Problem

Packages with vibrancy score < 10 (low GitHub activity) were classified as "End of Life" — the same label used for packages that are genuinely discontinued on pub.dev or marked dead in `known_issues.json`.

**Example:** `awesome_notifications_core` scored 0/10 and was labeled "End of Life" despite its parent package `awesome_notifications` being updated 31 days ago. The package isn't dead — it just has low GitHub activity metrics.

## Root Cause

`classifyStatus()` in `status-classifier.ts` used score < 10 as the fallback tier for "End of Life", conflating low maintenance activity with genuine project death.

## Fix

Added new `'stale'` VibrancyCategory for packages with score < 10. Reserved `'end-of-life'` exclusively for packages that are:
- Discontinued on pub.dev (`isDiscontinued`)
- Listed in `known_issues.json` with `status: "end_of_life"`
- Archived on GitHub (`isArchived`)

### Classification Table

| Score | Category | Meaning |
|-------|----------|---------|
| >= 70 | vibrant | Active, well-maintained |
| 40-69 | quiet | Moderate activity |
| 10-39 | legacy-locked | Low activity, may be stuck |
| < 10 | **stale** | Very low maintenance activity |
| N/A | end-of-life | Genuinely dead (hard override) |

### Files Changed

- `types.ts` — added `'stale'` to `VibrancyCategory` union
- `status-classifier.ts` — score < 10 returns `'stale'`; added stale to icon/severity/label/count
- `budget-checker.ts` — added `staleCount` and `maxStale` budget dimension
- `types-extended.ts` — added `maxStale` to `BudgetConfig` and `CiThresholds`
- `consolidate-insights.ts` — stale problem weight (25, between EOL 30 and legacy 20)
- `problem-types.ts`, `problem-collector.ts` — stale problem handling
- `diagnostics.ts` — stale gets "Review" verb and Information severity
- `vibrancy-state.ts` — stale counted in problemCount
- `threshold-suggester.ts` — stale threshold suggestion
- `report-exporter.ts` — stale in markdown/JSON reports
- UI files: codelens-formatter, tree-item-classes, indicator-config, detail-view-styles, report-html, comparison-html
- `package.json` — `budget.maxStale` setting
- All corresponding test files updated with stale coverage

### Verification

- TypeScript compiles cleanly (source + tests)
- 141 standalone tests passing
- Tests requiring VS Code extension host type-check correctly

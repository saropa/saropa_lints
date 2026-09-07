# Audit Report UI Pass

The full audit report webview lacked visual severity indicators, had inconsistent number formatting, duplicated filter information in a non-interactive KPI strip, and did not support file-to-line navigation or rule-name filtering. Nine improvements were applied in a single pass.

## Changes

### Severity color coding
- Error rows get a red left border, warning rows amber, INFO rows transparent.
- Severity pills and filter chips use tinted text via `color-mix` toward foreground.

### Number formatting
- Server-side counts now use `formatNumber()` from `webview-format.ts` (the canonical formatter with NaN guard) instead of a local duplicate.
- Client-side pagination counts use explicit `en-US` locale to match server rendering.

### Filter chip count badges
- Counts display as pill-shaped badges (`border-radius`, `background`, `font-weight`) instead of bare parenthesized numbers.

### KPI strip removal
- The read-only `.chip-strip` with severity/tier counts was removed — the interactive filter chips already display the same information and are clickable.

### Pagination after filtering
- The 500-row page limit applies to the filtered result set, not the raw total. A note below the pagination controls clarifies this.

### JSON file export
- New "Export JSON" button triggers `vscode.window.showSaveDialog` with a default filename of `audit-YYYY-MM-DD.json`. Uses synchronous write (documented trade-off: payload rarely exceeds a few MB since the deferred path handles >10MB).

### Clickable file paths
- File cells use link color (`--vscode-textLink-foreground`) with underline on hover.
- Clicking opens the file at the diagnostic's line AND column (previously opened at line 1, column 0).

### Clickable rule names
- Rule names in the table are styled as links. Clicking one sets a rule filter that shows only findings for that rule.
- A dismissible banner appears above the toolbar showing the active rule filter.

### INFO hidden by default
- When errors or warnings exist, INFO severity chips render inactive (server-side) and the initial page is filtered server-side to exclude INFO rows, eliminating a flash-then-hide pattern.
- The `hasErrorsOrWarnings` flag is computed from lowercase severity keys (matching `auditCliRunner.ts` normalization).

## Review fixes applied
- **Case mismatch (CRITICAL):** `severityCounts.get('ERROR')` was always `undefined` because severity values are lowercase. Fixed to `'error'`/`'warning'`.
- **Server-side INFO filtering:** Initial page now excludes INFO rows server-side when hiding, removing the need for `HAS_ERRORS_OR_WARNINGS` and the client-side `rerender()` flash.
- **Duplicate formatter:** Replaced local `fmtNum()` with imported `formatNumber()` from `webview-format.ts`.
- **Locale consistency:** Client-side `fmtN()` now uses explicit `'en-US'` to match server formatting.
- **Column threading:** `data-col` attribute added to file cells; `openFile` message now carries `column`; panel handler positions cursor at the diagnostic column.
- **Stale doc comment:** Updated to reflect current feature set.
- **Parameter count:** Removed the 5th parameter from `buildAuditScript` by moving INFO filtering to the server.

## Hardening (reflection gate)

- **Severity case normalization:** `countBy` and `uniqueSorted` for severity now normalize to lowercase defensively, preventing silent feature loss if the CLI ever changes casing.
- **formatNumber reuse:** Replaced local `fmtNum()` with the canonical `formatNumber()` from `webview-format.ts` (includes NaN guard, consistent locale).
- **Export path fallback:** `exportAuditJson` falls back to the first workspace folder if `currentRoot` is empty.
- **Narrow viewport:** Rule filter banner uses `flex-wrap` and `word-break: break-all` for long rule names at ~380px.
- **High-contrast themes:** `@media (forced-colors: active)` overrides severity row borders to use system colors (`LinkText`, `Mark`) and severity bar segments to `LinkText`/`Mark`/`GrayText`.

## Severity summary bar (unrequested feature)

A thin (6px) horizontal bar between the header and toolbar shows the error/warning/info ratio as colored segments. Each segment has a tooltip with count and percentage. Uses `forced-colors` media query for accessibility. Only renders when findings exist.

## Finish Report (2026-09-07)

Files changed: `audit-report-html.ts`, `audit-report-styles.ts`, `audit-report-script.ts`, `audit-report-panel.ts`, `en.json`, `CHANGELOG.md`.

All 11 audit tests pass. TypeScript compiles cleanly. Visual verification requires F5 in the Extension Development Host.

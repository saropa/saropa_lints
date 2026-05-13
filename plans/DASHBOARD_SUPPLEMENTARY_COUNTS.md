# Dashboard Supplementary Counts

**Status:** Implemented
**Origin:** [#224](https://github.com/saropa/saropa_lints/issues/224) — user reported 354 saropa vs 392 `dart analyze` + 20 TODOs = 412 Problems view items

## Context

The saropa dashboard reads `violations.json`, which only contains saropa_lints custom rule violations. `dart analyze` and VS Code's Problems panel also show built-in Dart SDK lints (`unused_import`, `prefer_const_declarations`, etc.) and `todo` diagnostics that saropa doesn't produce. Users comparing the dashboard count to the Problems panel see a gap and assume something is broken.

The fix is to make the gap **visible and reconcilable from the dashboard itself**, without contaminating the health score or triage workflow. The same discoverability problem applies to the existing `saropaLints.todosAndHacks.workspaceScanEnabled` toggle — users who would benefit from TODO/HACK tracking never find it because it's only reachable via Settings UI. This plan exposes all three controls (analyzer-side dart lints, analyzer-side TODOs, scanner-side TODOs/HACKs) using a single dashboard-native pill pattern.

## Design Decisions

### D1: Data source — `vscode.languages.getDiagnostics()`

Read VS Code's live diagnostics at dashboard render time. No timer, no separate cache, no new background task. The call is cheap (reads already-computed VS Code state). Recomputed on every dashboard rebuild AND on `vscode.languages.onDidChangeDiagnostics` (debounced) so the line stays in sync with the Problems panel as analysis runs.

### D2: Counting method — subtraction, with honest labeling

All saropa violations flow through the Dart analyzer plugin and surface in diagnostics with `source: "dart"` alongside built-in Dart lints AND any other `custom_lint` plugins the workspace uses (riverpod_lint, etc.). Count all `source === "dart"` diagnostics on `.dart` files, subtract saropa's `totalAfterDisable` count, clamp to 0. TODOs counted separately by `code === "todo"`.

```
allDartDiags    = getDiagnostics() filtered to .dart files, source "dart"
todoCount       = allDartDiags where code === "todo"
nonTodoDartDiag = allDartDiags - todoCount
otherAnalyzer   = max(0, nonTodoDartDiag - saropaViolationCount)
```

**Label this bucket "other analyzer findings", NOT "Dart lints".** The bucket includes built-in Dart SDK lints, `flutter_lints`, and any third-party `custom_lint` plugins. Calling it "Dart lints" is wrong — riverpod_lint findings would silently land there.

**Spike prerequisite (Step 0):** before shipping, verify in a real workspace that every saropa rule reports under `source: "dart"`. If any rule uses a different source string, subtraction double-counts silently.

### D3: Display — inline toggle pills on the dashboard status line

The toggle and the data live on the same surface. The status line already hosts the findings count, freshness, drift status, and rule count — that's where users look. Each supplementary source has three render states:

| Setting state | Counts > 0 | Render |
|---|---|---|
| OFF | n/a | Muted "promo" pill — clickable, flips setting ON. Example: `+? other analyzer findings — show` |
| ON | == 0 | Pill hidden (nothing to surface; avoids zero-clutter) |
| ON | > 0 | Count pill — clickable, flips setting OFF. Example: `+38 other analyzer findings` |

The promo pill is what closes the discoverability gap. A user who has never opened Settings sees the affordance directly under the title, decides whether they want the extra context, and toggles it with a single click. No sidebar trip, no command palette, no settings search.

KPI cards, health score, status bar, filtering, and quick fixes remain saropa-only. The pills are display-and-toggle only — they never feed `filterDisabledFromData`, `buildFilteredIndex`, or health scoring.

### D4: TODO sources — two independent toggles, two distinct meanings

Two separate pills, because they answer different questions:

- **`saropaLints.includeAnalyzerTodosInCount`** (new) — counts analyzer diagnostics with `code === "todo"`. Matches what the Problems panel shows. Answers "why does the Problems panel count differ from saropa?"
- **`saropaLints.todosAndHacks.workspaceScanEnabled`** (existing) — file-system scanner counting `// TODO` / `// HACK` markers. Answers "how many open TODOs/HACKs are in this workspace?"

The existing scanner already renders a pill ([violationsDashboardHtml.ts:267-269](extension/src/views/violationsDashboardHtml.ts#L267-L269)) when enabled, but goes invisible when disabled — that's the discoverability bug. Promote it to the same three-state pattern as the new pills so users who'd benefit from it can find it.

Counts may not match exactly between the two sources (scanner reads files; analyzer reads parsed AST and respects ignores). That's correct — they answer different questions. The tooltip on each pill discloses the source.

### D5: Defaults — all OFF

Existing users see no change to populated state. Each promo pill renders only when the dashboard could plausibly help — i.e. there's at least one non-saropa diagnostic in the buffer, OR the scanner is off but `.dart` files exist. (Detail in Step 6.) This keeps the hero clean for users who don't have the gap.

### D6: Stale data — live recompute, honest disclosure

`Math.max(0, ...)` handles arithmetic edge cases. To prevent the supplementary line going stale right after analysis (when violations.json has updated but VS Code hasn't re-reported diagnostics yet, or vice versa), wire `vscode.languages.onDidChangeDiagnostics` to debounce-refresh the supplementary line only (no full dashboard rebuild — too expensive). Tooltip text on each pill: "Live from VS Code Problems panel. Updates as analysis completes."

## Implementation Steps

### Step 0: Source-string spike (BLOCKING)

Before any other work, in a representative workspace with saropa lints enabled:
1. Run `vscode.languages.getDiagnostics()` from a scratch extension command.
2. Log distinct `(diagnostic.source, diagnostic.code)` tuples for `.dart` files.
3. Confirm every saropa rule appears under `source: "dart"`. Note any outliers — they break the subtraction premise and need a different counting strategy (e.g. rule-name allowlist).

If outliers exist, return to design before proceeding.

### Step 1: New module — `supplementaryDiagnostics.ts`

**New file:** `extension/src/supplementaryDiagnostics.ts`

```typescript
export interface SupplementaryDiagnosticCounts {
  otherAnalyzerCount: number;
  analyzerTodosCount: number;
}

export function countSupplementaryDiagnostics(
  saropaViolationCount: number,
): SupplementaryDiagnosticCounts
```

- Calls `vscode.languages.getDiagnostics()`
- Filters to `.dart` URIs, `source === "dart"`
- Separates `code === "todo"` from the rest (handles `Diagnostic.code` shape `string | number | { value; target } | undefined`)
- Subtracts `saropaViolationCount` from the non-TODO bucket, clamps to 0
- Pure function (takes `getDiagnostics` injectable for testability)

### Step 2: Settings in `package.json`

**File:** `extension/package.json`

Two NEW boolean properties (default: `false`):
```
saropaLints.includeOtherAnalyzerFindingsInDashboard
saropaLints.includeAnalyzerTodosInDashboard
```

Existing property already in place:
```
saropaLints.todosAndHacks.workspaceScanEnabled
```

Three toggle commands (two new, one new wrapping the existing setting):
```
saropaLints.toggleIncludeOtherAnalyzerFindingsInDashboard
saropaLints.toggleIncludeAnalyzerTodosInDashboard
saropaLints.toggleTodosAndHacksScanner   // new wrapper around the existing setting
```

The third command exists so the existing scanner toggle becomes invokable from the palette and from the pill click handler. The underlying setting key does not change.

### Step 3: NLS strings

**Files:** `extension/package.nls.json` + 24 locale files

6 new NLS keys (2 settings + 3 commands + 1 group), each translated.

Runtime i18n keys in `extension/src/i18n/locales/en.json` + 24 locales:
```
findingsDash.supplementary.otherAnalyzerOn        — "+{count} other analyzer findings"
findingsDash.supplementary.otherAnalyzerPromo     — "+? other analyzer findings — show"
findingsDash.supplementary.analyzerTodosOn        — "+{count} analyzer TODOs"
findingsDash.supplementary.analyzerTodosPromo     — "+? analyzer TODOs — show"
findingsDash.supplementary.scannerPromo           — "Enable TODO/HACK scanner"
findingsDash.supplementary.tooltipLive            — "Live from VS Code Problems panel. Updates as analysis completes."
findingsDash.supplementary.tooltipScanner         — "Saropa file-system scanner — counts open TODO/HACK markers in source."
findingsDash.supplementary.tooltipPromoClickToOn  — "Click to enable"
findingsDash.supplementary.tooltipCountClickToOff — "Click to hide"
```

### Step 4: Dashboard input interface

**File:** `extension/src/views/violationsDashboardHtml.ts` — line 84 interface

Add to `ViolationsDashboardHtmlInput`:
```typescript
supplementary: {
  // Settings state (always provided so the renderer can decide promo vs count vs hidden)
  otherAnalyzerEnabled: boolean;
  analyzerTodosEnabled: boolean;
  scannerEnabled: boolean;   // mirrors todoHackSnapshot.enabled but explicit
  // Live counts (computed regardless of toggle state so promo pills know whether to render)
  otherAnalyzerCount: number;
  analyzerTodosCount: number;
  // Heuristic: whether there are .dart files at all (scanner promo only renders if yes)
  hasDartFiles: boolean;
};
```

### Step 5: Compute and pass supplementary data

**File:** `extension/src/views/violationsWideReportView.ts` — `rebuildDashboardHtml()` ~line 244

Before the `renderViolationsDashboardHtml()` call:
- Read all three settings from config
- ALWAYS call `countSupplementaryDiagnostics(totalAfterDisable)` (counts are needed even when toggle is off, to decide promo-pill visibility)
- Pass the result into the render input

### Step 6: Render toggle pills inside the status line

**File:** `extension/src/views/violationsDashboardHtml.ts`

New function `buildSupplementaryPills(input)` returns an array of HTML pill strings (not a separate line). Inject them inside `buildStatusLine()` at [violationsDashboardHtml.ts:253-287](extension/src/views/violationsDashboardHtml.ts#L253-L287), between the rule-count pill and the trailing toolbar buttons.

Per-source decision matrix:

```
otherAnalyzer pill:
  enabled && count > 0   → "<span class='pill toggle on'  data-toggle='other'>+N other analyzer findings</span>"
  enabled && count == 0  → hidden (nothing to show)
  !enabled && count > 0  → "<span class='pill toggle promo' data-toggle='other'>+? other analyzer findings — show</span>"
  !enabled && count == 0 → hidden (no gap to expose)

analyzerTodos pill: same rules, swap labels
scanner pill:
  enabled  → existing "{N} TODO · {N} HACK" pill (preserve current behavior)
  !enabled && hasDartFiles → "<span class='pill toggle promo' data-toggle='scanner'>Enable TODO/HACK scanner</span>"
  !enabled && !hasDartFiles → hidden
```

The `data-toggle` attribute drives the click handler in Step 8.

### Step 7: CSS for toggle pills

**File:** `extension/src/views/violationsDashboardStyles.ts`

```css
.pill.toggle {
  cursor: pointer;
  user-select: none;
}
.pill.toggle:hover {
  background: var(--vscode-toolbar-hoverBackground);
}
.pill.toggle.promo {
  opacity: 0.65;
  border-style: dashed;
}
.pill.toggle.promo:hover {
  opacity: 1;
}
.pill.toggle.on {
  /* uses default neutral pill styling — no extra rule needed */
}
.pill.toggle:focus-visible {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
```

Promo pills use a dashed border + reduced opacity to telegraph "inactive but available." Hover restores full opacity. ON pills look like any other status pill.

### Step 8: Webview ↔ host message handler

**File:** `extension/src/views/violationsDashboardHtml.ts` — inline script section

Add a click handler in the existing webview script bundle:
```javascript
document.addEventListener('click', (e) => {
  const pill = e.target.closest('.pill.toggle');
  if (!pill) return;
  vscode.postMessage({ type: 'toggleSupplementary', source: pill.dataset.toggle });
});
```

**File:** `extension/src/views/violationsWideReportView.ts` — message handler

Add a case for `toggleSupplementary` that maps `source` (`'other' | 'todos' | 'scanner'`) to the matching toggle command and executes it. Existing config-change handlers already trigger dashboard refresh.

### Step 9: Toggle commands in `extension.ts`

**File:** `extension/src/extension.ts`

Three `registerCommand` calls following the `toggleRunAnalysisAfterConfigChange` pattern (read current value, invert, write to workspace config, refresh). The third command (`toggleTodosAndHacksScanner`) writes to the existing `saropaLints.todosAndHacks.workspaceScanEnabled` key — no migration needed.

Extend the existing `onDidChangeConfiguration` handler (~line 529):
```typescript
if (e.affectsConfiguration('saropaLints.includeOtherAnalyzerFindingsInDashboard') ||
    e.affectsConfiguration('saropaLints.includeAnalyzerTodosInDashboard')) {
  refreshFindingsDashboardIfOpen(context);
}
// scanner toggle already triggers refresh via existing handler
```

### Step 10: Command catalog entries

**File:** `extension/src/views/commandCatalogRegistry.ts`

Three entries in `Setup & Configuration` so the toggles are discoverable from the command palette and Setup catalog. The catalog is the project's flat command index — it is NOT a sidebar config surface, so this is consistent with the "no standalone configs in the sidebar" rule.

**Explicitly NOT modified:**
- `configTree.ts` — toggles are exposed on the dashboard itself, not as standalone sidebar rows.
- `summaryTree.ts` — count info lives on the dashboard pill; duplicating it in the sidebar tree adds noise.

### Step 11: Live diagnostics refresh

**File:** `extension/src/views/violationsWideReportView.ts`

Subscribe to `vscode.languages.onDidChangeDiagnostics`, debounced ~500ms. On fire, if any supplementary toggle is ON and the dashboard panel is visible, recompute supplementary counts and post a `updateSupplementary` message to the webview. Webview script updates only the pill text (avoid full HTML rebuild).

For the no-toggle-on case, still recompute the *counts* so the promo pills can appear/disappear as diagnostics change. Skip the postMessage entirely if nothing visible would change (debounced equality check).

### Step 12: Unit tests

**File:** `extension/src/test/supplementaryDiagnostics.test.ts`

Mock `vscode.languages.getDiagnostics()` and cover:
- Empty diagnostics → both counts 0
- Only-saropa → both counts 0
- Mixed sources (`"dart"`, `"saropa"`, `"drift"`, custom strings) → only `"dart"` counted
- `code` shape variations (string `"todo"`, number, object `{ value: "todo", target: ... }`, undefined)
- Non-`.dart` files filtered out
- Saropa count > raw count → clamp to 0
- Realistic mixed scenario (matches the issue #224 numbers: saropa=354, total dart=392, todos=20, expect other=18, todos=20)

**File:** `extension/src/test/views/violationsDashboardHtml.test.ts` — extend existing

Cover the three-state pill rendering per source (off/promo/on) × (count==0/count>0).

### Step 13: CHANGELOG

**File:** `CHANGELOG.md`

Entry under `[Unreleased]`:
```
### Added
- Findings Dashboard: optional supplementary pills for analyzer-side findings and TODOs outside saropa's rule set, plus a discoverability promo for the existing TODO/HACK scanner. Surfaces the gap between saropa's count and the Problems panel count (#224). Three workspace settings, all default off, toggleable directly from the dashboard.
```

## Files Modified

| File | Change |
|------|--------|
| `extension/src/supplementaryDiagnostics.ts` | **NEW** — counter module (~40 lines) |
| `extension/src/test/supplementaryDiagnostics.test.ts` | **NEW** — unit tests |
| `extension/package.json` | 2 new settings + 3 toggle commands |
| `extension/package.nls.json` | NLS keys for new settings/commands |
| `extension/package.nls.*.json` (24 files) | Same keys translated |
| `extension/src/i18n/locales/en.json` | 9 runtime i18n keys |
| `extension/src/i18n/locales/*.json` (24 files) | Same keys translated |
| `extension/src/views/violationsDashboardHtml.ts` | Interface field + pill renderer + webview click handler |
| `extension/src/views/violationsDashboardStyles.ts` | CSS for `.pill.toggle` states |
| `extension/src/views/violationsWideReportView.ts` | Compute + pass supplementary data + message handler + onDidChangeDiagnostics subscription |
| `extension/src/views/commandCatalogRegistry.ts` | 3 catalog entries |
| `extension/src/extension.ts` | 3 toggle commands + config change handler |
| `extension/src/test/views/violationsDashboardHtml.test.ts` | Pill-state coverage |
| `CHANGELOG.md` | Unreleased entry |

## What Does NOT Change

- **`healthScore.ts`** — score stays saropa-only
- **Status bar text** — findings count stays saropa-only
- **KPI cards** — remain saropa filter buttons
- **`filterDisabledFromData()`** — no supplementary data mixed in
- **`buildFilteredIndex()`** — filtering stays saropa-only
- **Quick fixes** — unaffected
- **Inline annotations** — unaffected (saropa violations only)
- **`configTree.ts`** — no new sidebar config rows (toggles live on the dashboard)
- **`summaryTree.ts`** — no new sidebar count rows (counts live on the dashboard pill)
- **`saropaLints.todosAndHacks.workspaceScanEnabled` setting key** — unchanged, just exposed via a new toggle command and dashboard pill

## Verification

1. **Step 0 passed:** spike confirmed all saropa rules report under `source: "dart"`.
2. **TypeScript compiles:** `npx tsc --noEmit` in `extension/`.
3. **NLS keys resolve:** `npm run verify-nls-keys` in `extension/`.
4. **Default off:** Fresh workspace with non-saropa lints present shows promo pills (dashed, muted) on the dashboard; no count pills.
5. **Promo click:** Clicking a promo pill flips the setting ON, dashboard refreshes, pill becomes a count pill within ~1 frame.
6. **Count click:** Clicking a count pill flips the setting OFF, pill returns to promo (or hides if count is 0).
7. **Counts match Problems panel:** Compare `+N other analyzer findings` and `+N analyzer TODOs` against Problems panel (filter to .dart files; manually count non-saropa lints and todo diagnostics).
8. **Reconciliation:** saropa count + other-analyzer + analyzer-todos == total Problems panel count for .dart files.
9. **Health score untouched:** Gauge score doesn't change when any pill toggles.
10. **Scanner promo discovers existing feature:** Fresh workspace with .dart files but scanner disabled shows "Enable TODO/HACK scanner" promo pill; clicking it enables the existing scanner and the existing TODO/HACK pill replaces the promo.
11. **Live refresh:** Edit a file to add `// TODO: x`, save, wait for analysis — analyzer TODOs pill updates without manual dashboard refresh.
12. **No sidebar pollution:** Sidebar config tree and summary tree show no new rows.
13. **Command palette:** Searching "saropa toggle" surfaces all three commands.
14. **Multi-plugin honesty:** In a workspace with `riverpod_lint` also enabled, the "other analyzer findings" pill counts riverpod findings (not just SDK lints) — label is accurate.
15. **Stale handling:** Run analysis mid-render; if timing mismatch, supplementary line never shows negative numbers.

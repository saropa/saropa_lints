# Plan: Package Vibrancy Report Hardening

> **Origin:** This plan was originally misfiled in the `saropa-log-capture` repo
> (as `plans/103_plan-pubspec-vibrancy-report-hardening.md`). The work it
> describes is the **Package Vibrancy report** feature in this repo
> (`extension/src/vibrancy/`). Moved here 2026-06-13.

## Status (audited 2026-06-13; archived 2026-06-14)

**ARCHIVED RECORD.** 17 of 19 acceptance checks verified DONE against
`extension/src/vibrancy/` code. The two items that were still open when this
plan was archived now live in their own active plan:
`plans/PACKAGE_VIBRANCY_REPORT_REMAINING.md` (WS5 published-age regression
fixture; WS6 graph zoom/pan). This file is the completed record of everything
that shipped, including the filter-sync work in the Finish Report below.

Resolved 2026-06-14:

- **WS6 — graph filter sync (DONE).** `renderNetwork` is now a hoisted
  function called from `applyFilters()` (and once at init). It reads each
  table row's visibility and draws a node only for a visible package and an
  edge only when both endpoints are visible, so the graph tracks the search
  box, age slider, dev-deps toggle, presets, and chart filters
  (`views/report-script.ts`).

Minor: WS3 missing-link target is a silent no-op rather than the spec's
"non-clickable text with reason tooltip" (`views/report-script.ts:1086`).

---

**Problem:** The current pubspec vibrancy report UI has several correctness and usability gaps: footprint controls are unclear, navigation between dependency rows is weak, date/age data appears inaccurate, sorting/filtering is incomplete, and report export flows are missing basic quality-of-life behavior.

**Reference artifact:** `D:\src\contacts\reports\20260428\20260428_pubspec_vibrancy.json`

---

## Scope

This plan covers:

- Report action controls (`Copy`, `Save`) and persisted JSON snapshots.
- Table interactions (sorting, linking, tooltips, filtering, alignment).
- Dependency graph visibility (network diagram).
- Data correctness fixes for published age and category sorting semantics.

This plan does not include:

- Re-scoring the package health algorithm itself.
- New external services; all behavior remains local-first.

---

## Workstreams

### 1) Export + Save UX

Addresses:

- `#2` Rename `Copy all JSON` button to `Copy`.
- `#2` Add `Save` button writing timestamped JSON snapshots in reports folders.

Implementation:

- Rename command label and tooltip to `Copy`.
- Add a new `Save` action that:
  - Uses report date folder (example: `20260428`) or creates it.
  - Writes `YYYYMMDD_HHmmss_pubspec_vibrancy.json`.
  - Uses local path pattern: `D:\src\contacts\reports\YYYYMMDD\...`.
- Add success/failure toast with saved path.

Acceptance checks:

- Copy button label is exactly `Copy`.
- Save creates one new file per click with no overwrite collisions.
- Saved JSON matches the currently displayed filtered/sorted dataset contract (define whether raw/full or view-state; choose one explicitly and document it).

---

### 2) Size + Footprint Clarity

Addresses:

- `#1` Footprint toggles (`Own`, `+Unique`, `+All`) only visibly changing on `All`.
- `#1` Unexpected tiny delta (for example +5MB over 67MB) despite package expectations.
- `#3` `Size` number should link to the package folder on local device.

Implementation:

- Audit footprint computation layers:
  - `Own`: files directly in package.
  - `+Unique`: transitives not already counted elsewhere.
  - `+All`: full transitive closure.
- Add explicit legend + hover description for each mode.
- Show per-mode breakdown in tooltip (`own`, `unique add`, `all add`) so changes are visible even when small.
- Make `Size` cell clickable:
  - Resolve package folder path on disk.
  - Open folder in OS explorer.
  - Gracefully handle missing path (disabled link + tooltip).

Acceptance checks:

- Switching between `Own` and `+Unique` changes either value or the breakdown tooltip for packages with unique transitives.
- `Size` click opens the expected folder.
- Missing folder does not throw; user gets clear feedback.

---

### 3) Dependency Navigation + Back Stack

Addresses:

- `#5` Transitive dependency names in `Deps` column should link to package rows.
- `#5` Back button support after in-table navigation.
- `#6` Transitives column right alignment + tooltip list with links.
- `#12` File references should be clickable (for example `lib/...dart:1`).

Implementation:

- Convert dependency names to in-table deep links:
  - Scroll to + highlight target package row.
  - If target missing, keep non-clickable text with a reason tooltip.
- Implement lightweight navigation history stack:
  - Push source row on each dependency jump.
  - Back action restores previous scroll position and highlight.
- Right-align numeric transitive columns.
- Add hover tooltip panel listing linked transitives.
- Make file references clickable:
  - Parse `path:line`.
  - Open file locally and jump to line when available.

Acceptance checks:

- Clicking `material_color_utilities` (or similar) jumps to that row.
- Back returns to prior row/scroll state.
- Transitives numeric columns are right aligned.
- File reference links open at correct file + line.

---

### 4) Filtering + Sort Semantics

Addresses:

- `#7` Published age slider filter.
- `#8` Toggle include/exclude dev dependencies.
- `#10` Category sorting order incorrect.
- `#14` Deps column sorting missing.

Implementation:

- Add published-age range slider (months) with min/max labels.
- Add include-dev-dependencies toggle:
  - Off = production deps only.
  - On = include `dev_dependencies`.
- Fix category sort comparator:
  - Primary: category A→Z / Z→A.
  - Secondary: package name ascending.
- Add sort behavior for deps column:
  - Sort by transitive count.
  - Tie-breaker by package name.

Acceptance checks:

- Age slider changes visible rows predictably.
- Dev toggle updates row set and totals.
- Category sort cycles `A-Z`, `Z-A`, then reset/default.
- Deps column sort cycles in same pattern and is stable.

---

### 5) Data Accuracy + Explainability

Addresses:

- `#9` Project package letter grade needs "why" tooltip.
- `#11` Published age is wrong for some packages.
- `#13` Clarify the `🌳` emoji in deps items.

Implementation:

- Grade tooltip:
  - Show component contributions (resolution velocity, engagement, popularity, trust).
  - Include total score and threshold mapping to letter grade.
- Fix age calculation:
  - Use UTC date diff based on package `published` field.
  - Use month-aware calculation (not naive day/365 truncation).
  - Add regression fixture including `device_calendar 4.3.3`.
- Replace unexplained emoji with:
  - Either text label (`Transitive`) or
  - emoji + explicit legend tooltip.

Acceptance checks:

- Hovering grade always explains score composition and grade band.
- Known example (`device_calendar 4.3.3`) reports expected age range.
- No unexplained symbolic markers remain in deps cells.

---

### 6) Dependency Relationship Visualization

Addresses:

- `#4` Need a network diagram to understand package relationships.

Implementation:

- Add optional graph view panel:
  - Nodes: direct dependencies + selected transitives.
  - Edges: dependency relationships.
  - Basic controls: zoom, pan, focus selected package.
- Start with a lightweight local graph renderer already used in project stack (no heavy architecture change).
- Keep table as source of truth; graph mirrors current filters (age, dev toggle, etc.).

Acceptance checks:

- Opening graph view renders nodes/edges for current filtered dataset.
- Clicking a node highlights corresponding table row.
- Large graphs remain usable (minimum: no blocking freeze for typical project size).

---

## Delivery Sequence

1. **Data correctness first:** published age + category/deps sorting.
2. **Navigation quality:** dependency links, file links, back support.
3. **Export controls:** `Copy` rename + `Save` snapshots.
4. **Footprint/size usability:** mode clarity + local folder links.
5. **Filtering controls:** age slider + dev toggle.
6. **Explainability polish:** grade tooltip + emoji cleanup.
7. **Graph view:** network diagram behind a feature toggle until stable.

---

## Test Plan

- Unit tests:
  - Date-age calculation (boundary months, leap years, timezone neutrality).
  - Sort comparators for category and deps columns.
  - Filename generation (`YYYYMMDD_HHmmss_pubspec_vibrancy.json`).
- UI/integration tests:
  - Dependency deep link + back behavior.
  - File reference click opens file/line.
  - Age slider and dev toggle interactions.
  - Footprint mode toggle behavior and tooltips.
- Manual verification:
  - Run report against provided reference JSON.
  - Validate at least 3 known packages with real pub.dev publish dates.

---

## Open Decisions (Need Product Call)

- Should `Save` export full raw data or current filtered/sorted view snapshot?
- For `Size` folder links, what is the authoritative local package root when multiple caches/workspaces exist?
- Should graph view include all transitives by default, or start collapsed at depth=1?

---

## Risks

- Large dependency graphs can degrade rendering performance; guard with depth limits and progressive rendering.
- Local file/folder linking is OS/path-environment sensitive; include robust fallback messaging.
- Tooltip-heavy UI may become noisy; keep content concise and predictable.

---

## Finish Report (2026-06-14)

### Scope

VS Code extension webview only (`extension/src/vibrancy/views/report-script.ts`).
No Dart lint-rule, analyzer, or `example/` change. Closes the WS6 graph
filter-sync item; two items remain open and are tracked in the Status block at
the top of this plan (WS5 published-age regression fixture; WS6 graph zoom/pan).

### Problem

The Package Vibrancy report's dependency network diagram rendered once, at page
load, from the full result set. Every table filter — the search box, the
published-age slider, the include-dev-dependencies toggle, the preset selector,
and the click-to-filter chart — left the graph unchanged, so the diagram showed
packages the table had filtered out of view. The table was the stated source of
truth, but the graph silently contradicted it.

### Change

`renderNetwork` was converted from a one-shot IIFE into a hoisted function
declaration and is now invoked from `applyFilters()` (the single site every
filter path already funnels through) and once explicitly at init. Before
drawing, it reads each `#pkg-body` row's `display` and builds a visible-name
set, then draws a direct node only when its package row is visible and an edge
only when both endpoints are visible. Edges to a filtered-out transitive are
dropped, and a fully-filtered graph shows a distinct
"No dependency relationship data for the current filters." message rather than
the load-time "No dependency relationship data." empty state.

The explicit init call is required because `restoreUIState()` returns early on a
first-ever open with no saved state and never reaches `applyFilters()`; without
the init call the graph would not draw at all on a cold start. The hoisted
declaration is what lets the earlier-defined `applyFilters()` call it.

### Verification

- `tsc --noEmit` (full extension typecheck): clean.
- `tsc -p tsconfig.test.json`: clean.
- The generated browser script was parsed with `new Function()` to confirm the
  embedded JS is syntactically valid (the file is a single template literal, so
  the TypeScript compiler does not check the script body).
- The visibility-filter algorithm was exercised against a stub DOM: an all-
  visible set keeps every node and edge; hiding a dev dependency and a shared
  transitive drops that node and the corresponding edge; an all-hidden set
  yields the filtered-empty message.
- `report-html.test.ts` / `report-webview.test.ts`: 149 passing, including the
  `dep-network` panel-position test. Three pre-existing failures concern the
  Health Score panel rows and a references-column rename in `report-html.ts`
  (server-rendered HTML, untouched here) and are unrelated to this change.

### Localization note

The report client script (`getReportScript`) contains no `l10n()` calls; all of
its ~40 user-visible strings are hardcoded English. The script is browser-side
JavaScript embedded as a string, and the `l10n()` runtime executes in the
extension host, not the webview, so these strings sit outside the catalog
pipeline by construction. The one new empty-state string matches that existing
convention. Routing the whole client script through the catalog is a separate,
larger effort and is not part of this change.

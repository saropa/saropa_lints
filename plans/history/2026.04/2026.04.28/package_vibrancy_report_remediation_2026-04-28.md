# Package Vibrancy Report Remediation Plan (2026-04-28)

**Status:** Proposed - not started  
**Owner:** Extension / Package Vibrancy  
**Scope:** VS Code extension package vibrancy report UX, data integrity, and navigation

---

## Goal

Make the Package Vibrancy report accurate, navigable, and actionable for large dependency graphs.  
This plan addresses current regressions in footprint sizing, sorting, age correctness, table UX, JSON export workflow, and dependency relationship visibility.

Reference report used for validation:
- `D:\src\contacts\reports\20260428\20260428_pubspec_vibrancy.json`

---

## Reported Problems (Consolidated)

1. Footprint toggle (`Own`, `+ Unique`, `+ All`) behaves inconsistently; `All` is the only mode that visibly changes output, and delta appears too small for large package trees.
2. `Copy all JSON` label should be `Copy`; add a `Save` action to write dated JSON snapshot under project reports folder.
3. `Size` value should link to local package folder.
4. Need clearer package relationship visualization (network diagram).
5. Transitive dependency names in `Deps` should deep-link to matching table rows and support back navigation.
6. Transitives column should be right aligned and show tooltip list with package links.
7. Need Published Age filter slider.
8. Need toggle to include/exclude dev dependencies.
9. Project package letter grade needs tooltip explaining why.
10. Category sorting is incorrect; should be A-Z, Z-A, then package-name tiebreaker.
11. Published age calculation is wrong for some packages (example: `device_calendar`).
12. File references should be clickable local links (e.g. `lib/components/country/flag/country_flag.dart:1`).
13. Clarify/remove emoji (`🌳`) in deps items.
14. Deps column should be sortable.

---

## Architecture Areas Likely Affected

- `extension/src/vibrancy/views/report-html.ts`
- `extension/src/vibrancy/views/report-webview.ts`
- `extension/src/vibrancy/views/report-styles.ts`
- `extension/src/vibrancy/scoring/*` (if grade rationale or category comparators live here)
- `extension/src/vibrancy/types.ts`
- `extension/src/vibrancy/services/*` (footprint, publish-date normalization, deps graph construction)
- `extension/src/test/vibrancy/**` (unit and integration coverage)

---

## Phased Delivery

## Phase 1 - Data Correctness (do first)

### 1. Footprint toggle correctness
**Hypothesis:** toggle state is only partially wired to recomputation, or source map for `Own/+Unique/+All` reuses same aggregate set except for `All`.

**Plan**
- Trace footprint computation pipeline from raw package file map -> grouped totals -> rendered cell.
- Add explicit mode enum and unit-tested aggregator:
  - `own`: only files attributable to package itself.
  - `unique`: package + transitives not already counted in upstream selection.
  - `all`: full transitive closure footprint.
- Ensure mode switch invalidates memoized totals and triggers re-render.
- Add per-row diagnostic metadata in debug mode (`ownBytes`, `uniqueBytes`, `allBytes`, `transitiveCount`).

**Acceptance**
- Switching among all three modes updates both per-row and project totals every time.
- Example package (`crop_your_image`) shows expected jump between modes (not just `All`).

### 2. Published age accuracy
**Hypothesis:** date source fallback or timezone/rounding logic is wrong (e.g., using package creation date or tag date instead of selected version publish date).

**Plan**
- Standardize on resolved package-version publish timestamp.
- Normalize to UTC and compute age from day boundaries to avoid month/year drift.
- Add invariant tests around known fixtures (`device_calendar 4.3.3` and 3-5 other packages).

**Acceptance**
- Age string and numeric age match known pub.dev values within 1 day.
- Sorting/filtering by age uses same canonical numeric source.

### 3. Category and deps sort correctness
**Plan**
- Implement stable comparator chain for category:
  - primary: category label alphabetical (A-Z or Z-A per current sort direction)
  - secondary: package name ascending
- Add sortable comparator for deps column:
  - primary: transitive count numeric
  - secondary: package name ascending
- Ensure sort state is single-source-of-truth in table state model.

**Acceptance**
- Repeated sort cycles are deterministic.
- Category and deps both sortable with visible sort indicator.

---

## Phase 2 - Navigation and Interaction

### 4. Deps links + back support
**Plan**
- Convert each transitive package token into in-table anchor (`#pkg:<name>`).
- Add navigation history stack in report webview state:
  - push on package jump
  - `Back` action and keyboard `Alt+Left` handling when focus is in table context.
- Highlight target row on arrival.

**Acceptance**
- Clicking transitive package navigates to row and highlights it.
- Back returns to previous row/scroll position.

### 5. Transitives column UX
**Plan**
- Right-align numeric deps counts.
- On hover, show tooltip/popover listing transitive packages as links.
- Keep list virtualized/capped for very large graphs (`+N more` pattern).

**Acceptance**
- Column is right aligned.
- Tooltip opens quickly and links are clickable.

### 6. Clickable file references
**Plan**
- Parse `path:line` entries into commands that open file at location via extension host message bridge.
- Validate workspace-relative and absolute path resolution.

**Acceptance**
- Clicking `lib/.../country_flag.dart:1` opens editor at line 1.

### 7. Size links to local package folder
**Plan**
- Attach local cache/project package path metadata to each row.
- Render `Size` as clickable link/icon action to open folder in explorer.
- Fallback state for missing folder (`Not available locally`).

**Acceptance**
- Clicking size opens package folder for cached dependencies.

---

## Phase 3 - Controls and Explainability

### 8. Replace `Copy all JSON` label and add `Save`
**Plan**
- Rename action to `Copy`.
- Add `Save` command writing current report JSON to:
  - `<project>/reports/<YYYYMMDD>/<YYYYMMDD>_<HHmmss>pubspec_vibrancy.json`
- Ensure directory creation and collision-safe naming.
- Show success toast with full path and quick open action.

**Acceptance**
- `Copy` copies exactly current view JSON.
- `Save` writes file under date folder and confirms output path.

### 9. Published age slider filter
**Plan**
- Add min-max slider bound to numeric age (days or months).
- Keep filter state in webview session and optional persisted defaults.

**Acceptance**
- Rows update immediately as slider changes.
- Works with other filters/sorts concurrently.

### 10. Include dev dependencies toggle
**Plan**
- Add top-level toggle: `Include dev dependencies`.
- Ensure all derived metrics (counts/grades/deps graph) recompute with toggle state.

**Acceptance**
- Turning off removes dev-only rows and adjusts totals.

### 11. Grade rationale tooltip
**Plan**
- Add tooltip for project letter grade with weighted breakdown:
  - score
  - major contributing dimensions
  - top penalties / highest-risk contributors
- Reuse existing scoring explanation copy where possible.

**Acceptance**
- Tooltip clearly answers "why this grade."

### 12. Emoji decision for deps (`🌳`)
**Plan**
- Decide one of:
  - remove emoji entirely, or
  - gate behind `showIcons` preference and replace with textual badge.
- Align with existing report iconography.

**Acceptance**
- Deps cell no longer uses ambiguous/unexplained icon by default.

---

## Phase 4 - Relationship Visualization

### 13. Package network diagram
**Plan**
- Add relationship view (new tab/panel in report webview):
  - nodes: packages
  - edges: dependency relation
  - node color: category/grade
  - optional edge direction + depth limit
- Interactions:
  - click node -> focus table row
  - search node by name
  - filter to selected package neighborhood

**Acceptance**
- User can visually trace transitive chains and identify hubs.
- Works for large graphs via clustering/level-of-detail fallback.

---

## Testing Strategy

- Unit tests:
  - footprint mode aggregator
  - publish-age normalization
  - category/deps comparators
  - save-path builder and timestamp naming
- UI/webview tests:
  - sort toggles
  - deps link navigation + back stack
  - file reference and size link actions
  - slider and dev-deps toggle recomputation
- Regression fixtures:
  - include provided `20260428_pubspec_vibrancy.json` plus synthetic graph fixture
- Manual validation:
  - run against `contacts` project and compare counts with pubspec lock + package cache reality

---

## Suggested Execution Order (Small PRs)

1. **PR A - Correctness Core**: footprint, publish-age fix, sort fixes (items 1, 10, 11, 14).
2. **PR B - Table Navigation UX**: deps links/back, tooltip links/right align, file refs, size link (items 3, 5, 6, 12).
3. **PR C - Commands & Filters**: `Copy`/`Save`, age slider, dev-deps toggle, grade tooltip, emoji cleanup (items 2, 7, 8, 9, 13).
4. **PR D - Graph View**: network diagram (item 4).

---

## Risks / Unknowns

- Local package folder mapping may differ between pub cache and workspace overlays.
- Network diagram can become noisy on large dependency sets; needs clustering and depth defaults.
- Footprint semantics (`unique`) must be documented to avoid confusion across teams.
- Save-path convention should handle multi-root workspaces and non-writable roots.

---

## Done Criteria

- All 14 items have passing tests or explicit deferred notes.
- Report metrics are deterministic across reruns with same inputs.
- New UX controls are discoverable and documented in walkthrough/help text.
- JSON export and save workflows are verified on Windows paths.

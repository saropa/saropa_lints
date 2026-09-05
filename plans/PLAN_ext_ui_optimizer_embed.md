# Plan — Analysis Optimizer embedded sort and bulk-select

**Created:** 2026-09-05 · **Status:** Not started
**Parent:** `PLAN_extension_ui_redesign.md` Phase 4 deferred item
**Scope:** TS-only, extension side. No Dart changes.
**Model:** Sonnet for implementation.

---

## 1. Problem

The Analysis Optimizer is embedded inside the Rules & Tiers Config file tab. The embedded
version handles scan, apply-one/all/selected, remove, fix-syntax, open-config, and preview
toggle. But it is missing two interactions the standalone panel has:

1. **Column sorting** — click a `<th>` header to sort the recommendations table by that column.
2. **Bulk-select** — the select-all checkbox toggles all `.rec-cb` checkboxes and the
   bulk-apply button's enabled state tracks how many are checked.

The HTML markup for both is already present in the embedded version (same `getEmbeddedBodyHtml()`
output) — only the client-side script is missing.

## 2. Current state

| Feature | Standalone (`analysisOptimizerScript.ts`) | Embed (`SCRIPT_OPTIMIZER_EMBED` in `configDashboardScript.ts`) |
|---|---|---|
| Column sort | `applySort()`, `markActiveHeader()`, `loadSortState()`/`saveSortState()` using `vscode.getState()`/`setState()` (lines 94-166) | Not present |
| Select-all | Toggles `.rec-cb` + calls `updateApplySelected()` to sync the bulk-apply button (lines 63-85) | Toggles `.rec-cb` (lines 990-996) but does NOT call `updateApplySelected()` — bulk-apply button disabled state is broken |

## 3. Work

### 3a. Bulk-select fix (small, mechanical)

The embed already has a `selectAll` change listener that toggles checkboxes. It just needs
`updateApplySelected()` — the function that counts checked boxes and enables/disables the
bulk-apply button.

1. Port `updateApplySelected()` from `analysisOptimizerScript.ts` (lines 80-85) into
   `SCRIPT_OPTIMIZER_EMBED`.
2. Call it after the `selectAll` toggle (line 996).
3. Wire it to individual `.rec-cb` `change` events too (standalone does this at line 75).

### 3b. Column sort (moderate)

1. Port `applySort()`, `markActiveHeader()` from `analysisOptimizerScript.ts` (lines 94-166)
   into `SCRIPT_OPTIMIZER_EMBED`.
2. **State persistence caveat:** The standalone uses `vscode.getState()`/`setState()` directly
   for sort state. The embed shares one `vscode` state object with the entire Config dashboard.
   Must namespace: use `optimizer.sortCol` / `optimizer.sortDir` sub-keys rather than top-level
   `sortCol` / `sortDir`. The existing embed state already uses `vscode.getState()` for the
   active tab — follow the same namespacing pattern.
3. **DOM scoping:** All DOM queries must be scoped to the `.optimizer-embed-body` container
   (or equivalent) rather than `document`, to avoid colliding with the host dashboard's own
   table headers and sort behavior.
4. Wire `<th>` click handlers within the optimizer section only.

## 4. Files touched

| File | Change |
|---|---|
| `rulePacks/configDashboardScript.ts` | Add `updateApplySelected()`, `applySort()`, `markActiveHeader()`, sort-state load/save to `SCRIPT_OPTIMIZER_EMBED`. Wire event listeners. |

One file. No new files, no HTML changes (the markup is already there), no message protocol
changes, no new l10n keys.

## 5. Verification checklist

- [ ] `tsc --noEmit` clean
- [ ] Select-all checkbox toggles all `.rec-cb` AND the bulk-apply button enables/disables
- [ ] Individual checkbox changes update the bulk-apply button state
- [ ] Clicking a column header sorts the table by that column (ascending, then descending)
- [ ] Sort state persists across tab switches within the same dashboard session
- [ ] Sort state does NOT collide with the host dashboard's own state (active tab, other cards)
- [ ] The standalone optimizer panel still works (regression check — `analysisOptimizerScript.ts`
      is not touched)
- [ ] Extension Dev Host visual check

## 6. Estimate

< 1 session (Sonnet). The standalone script is the reference implementation; the work is
porting ~100 lines of JS and adjusting DOM scoping + state namespacing.

## 7. Risks

- **State collision:** If the sort state keys collide with the dashboard's own `getState()`
  keys, switching tabs could clobber sort state or vice versa. Mitigated by namespacing
  under an `optimizer` sub-object.
- **DOM collision:** `document.querySelectorAll('th')` in the embed would also match the
  host dashboard's Config file tab tables. Mitigated by scoping all queries to the embed
  container.

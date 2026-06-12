# TODO — Project / Package vibrancy residual surfaces

**Created:** 2026-06-12
**Split from:** `OUTSTANDING_ITEMS_AUDIT.md` §5 (audit archived to `history/2026.06/2026.06.12/`)
**Subsystem:** `extension/src/vibrancy/`
**Source plans:** `history/2026.04/2026.04.28/project_vibrancy_report.md`,
`history/2026.04/2026.04.28/package_vibrancy_report_remediation_2026-04-28.md`

Most vibrancy plans shipped — tree-data, codelens, hover, code-action providers and
`vibrancy-history.ts` (history/trends) are present. The April "≈90% unbuilt" framing is stale.
These are the verified-unbuilt residuals + triage clusters.

## Status legend
- **[OPEN — verified]** `grep` finds no such surface — confirmed in the 2026-06-11 audit.
- **[OPEN — needs per-item confirm]** several sub-items may already be in the shipped UI; triage
  each against code before building.

---

## 5.1 Flight-risk predictive scoring (Phase 5) **[OPEN — verified — research-gated]**

`grep` finds no `flightRisk` surface. Research-gated in the source plan (scoring model undefined).

Action: research the scoring model first; do not build until the model is specified.

## 5.2 Package network / dependency diagram **[OPEN — verified]**

No `networkDiagram` / dependency-graph surface in vibrancy.

Action: build a dependency-graph view (nodes = packages, edges = deps) once 5.x priorities are set.
Self-contained webview; no blocker beyond prioritization.

## 5.3 package_vibrancy remediation — 14-item list **[DONE 2026-06-12 — already shipped]**

Triaged all 14 items from the source remediation plan against the current vibrancy report code
(`extension/src/vibrancy/views/report-html.ts`, `report-script.ts`, `report-styles.ts`,
`report-webview.ts`). **13 of 14 shipped after the April plan was written**; the 14th's goal was
already satisfied. Evidence per item:

1. Footprint toggle (own/+unique/+all) — DONE: three modes recalc per-row spans and the Total Size
   card (`report-html.ts` size spans + `report-script.ts` `updateTotalSizeSummary`).
2. JSON export labels — DONE: `Copy` label + a `Save` action writing a dated snapshot under the
   project reports folder (`report-webview.ts` `_saveReportJson`).
3. Size links to the local package folder — DONE (`.size-link` → `openSourceFolder`).
5. Deps deep-link + back navigation — DONE (`dep-nav-link` → `navigateToPackageRow`, `packageNavHistory`).
6. Transitives right-aligned + tooltip list — DONE (`.cell-right` + multi-line tooltip).
7. Published-age filter slider — DONE (`#age-max` range input + `maxAgeMonths` filter).
8. Dev-dependencies toggle — DONE (`#include-dev-toggle`).
9. Grade-rationale tooltip — DONE (`gradeTooltip` with score + distribution).
10. Category sort A-Z/Z-A + name tiebreaker — DONE (comparator chain in `report-script.ts`).
11. UTC day-boundary age from the resolved version timestamp — DONE (`computePublishedAgeMonths` uses
    `getUTC*`).
12. Clickable `path:line` file links — DONE (`.file-link` → `openFileRef`).
13. Tree emoji in deps — already absent from rendered output; only a stale code comment claimed a
    "tree icon". Corrected the comment to match reality (no behavior change).
14. Deps column sortable — DONE (`th('deps', …)` + numeric sort with name tiebreaker).
4. (Network/dependency diagram is §5.2 — tracked separately.)

No feature work remained. See the Finish Report below.

## 5.4 Cross-file semantic Usage collector **[OPEN — needs per-item confirm]**

The plan specifies analyzer element-resolution. Unconfirmed whether the shipped collector is still
name-based.

Action: read the current Usage collector — if name-based, the element-resolution upgrade is the
work; if already element-resolved, mark done.

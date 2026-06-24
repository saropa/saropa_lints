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

## 5.2 Package network / dependency diagram **[DONE — already shipped, audit grep miss]**

The audit reported "no dependency-graph surface" because it grepped for `networkDiagram`. The surface
exists under a different name: `buildNetworkSection` (extension/src/vibrancy/views/report-html.ts)
emits a `#dep-network` payload (nodes = direct packages, links = their transitives that are also
scanned packages), rendered by the `renderNetwork` force/column layout in `report-script.ts` as a
scrollable SVG inside the report's collapsible "network" panel. It carries its own prior bug-fix
history (the "chetracters" overlapping-label fix), confirming it is a real, exercised feature — not a
stub.

This satisfies §5.2's goal (nodes = packages, edges = deps). A second, standalone force-directed
webview was started during triage and then removed: it would have duplicated existing, working
functionality, which "search before creating" forbids. No build performed. See the Finish Report
below.

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

## 5.4 Cross-file semantic Usage collector **[SPLIT 2026-06-24 → own plan — confirmed name-based]**

Triaged 2026-06-24: the shipped Usage collector in `lib/src/cli/project_vibrancy.dart` is still
name-based — `_ReferenceVisitor` collects raw `SimpleIdentifier.name` text (no `staticElement`), and
`_computeUsageCounts` attributes counts via a bare `referencesByName[fn.name]` lookup. The
element-resolution upgrade is real outstanding work.

Split into its own detailed plan: `plans/PLAN_vibrancy_usage_collector_element_resolution.md`
(resolved reference collection, entry-point exclusions, tree-SHA usage cache, subprocess isolation +
NDJSON streaming, optional cascading-unused).

---

## Finish Report — 5.3 (2026-06-12)

### Package Vibrancy 14-item remediation — verified already implemented

The April 2026 remediation plan listed 14 fixes for the Package Vibrancy report (footprint-toggle
correctness, UTC age accuracy, sortable/deep-linked columns, filters, grade tooltip, and emoji
cleanup). A per-item code triage against the current report views found that the vibrancy UI shipped
all of the functional items in the interim — each backed by concrete code (the footprint mode
buttons and `updateTotalSizeSummary`, the `Copy`/`Save` export actions and `_saveReportJson`, the
`.size-link` / `.dep-nav-link` / `.file-link` handlers, the age slider and dev-deps toggle, the
grade tooltip, the category/deps comparators, and the UTC day-boundary age computation).

The only residue was the dependency-count cell (item 13): the rendered output already contained no
tree emoji, but a code comment still described showing "a tree icon." The comment was corrected to
state what the code actually renders (a plain count plus a shared-deps badge) and why the emoji was
dropped. No behavior changed; no user-facing string changed.

#### Verification

- Triage covered all 14 items with file:line evidence across `report-html.ts`, `report-script.ts`,
  `report-styles.ts`, and `report-webview.ts`.
- `npm run check-types` clean.

#### Outcome

No feature work required — §5.3 is closed as already-shipped. §5.1 (flight-risk scoring,
research-gated), §5.2 (dependency-graph view), and §5.4 (Usage collector) remain open in this plan.

---

## Finish Report — 5.2 (2026-06-12)

### Package dependency diagram — verified already implemented

A dependency diagram for the Package Vibrancy report was listed as unbuilt because the audit searched
for the symbol `networkDiagram`. The feature ships under a different name: `buildNetworkSection`
(extension/src/vibrancy/views/report-html.ts) derives nodes from the direct dependencies and links
from each package's transitives that are also scanned packages, emitting a `#dep-network` payload
that the `renderNetwork` routine in `report-script.ts` lays out as a scrollable SVG (direct packages
in a left column, unique transitives in a right column, edges between). It lives in a collapsible
"network" panel at the bottom of the report and carries documented prior bug fixes (an
overlapping-label defect), so it is an exercised feature rather than a placeholder.

Because that surface already answers "which packages depend on which," no new view was warranted. A
standalone force-directed model/webview begun during triage (`dependency-graph-model.ts`) was removed
before commit — shipping it would have duplicated working functionality, which the "search before
creating" rule prohibits.

#### Verification

- The diagram path was traced end to end: `buildNetworkSection` → `#dep-network[data-network]` →
  `renderNetwork` SVG output, plus its CSS (`.network-canvas`, `.network-wrap`) and l10n
  (`packageDashboard.network.summary`).
- No code shipped for §5.2; the started parallel model was deleted.

#### Outcome

§5.2 closed as already-shipped. Remaining open in this plan: §5.1 (flight-risk predictive scoring,
research-gated — a scoring model must be defined before any code) and §5.4 (whether the cross-file
Usage collector is name-based or element-resolved — a separate confirm-then-maybe-build item).

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

## 5.3 package_vibrancy remediation — 14-item list **[OPEN — needs per-item confirm]**

Triage each against the current vibrancy UI before building — several may already be shipped:

- footprint-toggle correctness
- UTC age accuracy
- deterministic category / deps sort
- deps-link back-navigation
- clickable `path:line`
- age-filter slider
- dev-deps toggle
- grade-rationale tooltip

Action: per-item — confirm presence/behavior in code, build only the genuinely-absent ones.

## 5.4 Cross-file semantic Usage collector **[OPEN — needs per-item confirm]**

The plan specifies analyzer element-resolution. Unconfirmed whether the shipped collector is still
name-based.

Action: read the current Usage collector — if name-based, the element-resolution upgrade is the
work; if already element-resolved, mark done.

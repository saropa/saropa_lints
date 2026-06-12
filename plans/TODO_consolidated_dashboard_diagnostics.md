# TODO — Consolidated dashboard + live-diagnostics remaining surfaces

**Created:** 2026-06-12
**Split from:** `OUTSTANDING_ITEMS_AUDIT.md` §1.1, §1.2, §6 (audit archived to `history/2026.06/2026.06.12/`)
**Subsystem:** `extension/src/views/consolidated/`, `extension/src/` diagnostics surfaces

The headline live-diagnostics + consolidated-dashboard work shipped 2026-06-12 (status-bar
score, Issues sidebar tree, `pushModel` error boundary, headless client eval-test). These are
the verified-open residuals.

## Status legend
- **[OPEN — verified]** confirmed still unbuilt by reading current code in the 2026-06-11 audit.
- **[OPEN — needs per-item confirm]** triage against code before building.

---

## 1. Consolidated webview — visual render + interaction **[OPEN — verified]**

The client ([consolidatedClient.ts](../extension/src/views/consolidated/consolidatedClient.ts))
now executes headlessly in CI ([consolidatedClient.test.ts](../extension/src/test/consolidatedClient.test.ts))
— load, `model`, `occurrences`, and `esc()` regex-survival are covered. Not covered:

- **Click / keyboard interaction** — depends on real DOM tree navigation (`closest`,
  `parentElement`) the recording-DOM stub does not model.
- **Visual render** — theme, layout, elevated stylesheet need a human F5 in the Extension
  Development Host, then a tuning pass.

Action: human render verification (`/verify` or manual F5), then tune. Pure-code automation of
event bubbling is not worth a jsdom dependency for one webview — leave as a launch-test item.

## 2. Surfaces still on the batch `violations.json` path **[OPEN — verified]**

`liveViolationsData.ts` centralizes the "prefer live diagnostics" read. The status-bar score and
Issues tree adopted it; these have not, and still show stale batch data between scans:

- [codeLensProvider.ts](../extension/src/codeLensProvider.ts)
- [issuesViewCommands.ts](../extension/src/commands/issuesViewCommands.ts)
- [configSuggestions.ts](../extension/src/config/configSuggestions.ts)
- inline annotations
- the triage dashboard
- the rule-packs panel

Action: migrate each to the `liveViolationsData` helper incrementally, with a debounced
`onDidChangeDiagnostics` listener (same pattern as the status-bar/Issues-tree migration). One
surface per commit; verify the displayed count tracks the editor's live diagnostics.

## 3. Supplementary analyzer-lints dashboard pill **[OPEN — needs per-item confirm]**

Source: `DASHBOARD_SUPPLEMENTARY_COUNTS.md` (2026-05-13). The TODO/HACK workspace-scan half
shipped ([todosAndHacksTree.ts](../extension/src/views/todosAndHacksTree.ts)). The
`showAnalyzerLints` dashboard pills (surface non-Saropa analyzer findings + analyzer TODOs
alongside the Saropa count) were **not found in code** during the audit.

Action: confirm the analyzer-lints pill + toggle is absent (grep `showAnalyzerLints`), then build
it if missing — a pill reading the same live-diagnostics source, filtered to non-`saropa_lints`
diagnostic sources, gated by a `showAnalyzerLints` setting.

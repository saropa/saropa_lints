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

## 2. Surfaces still on the batch `violations.json` path

`liveViolationsData.ts` centralizes the "prefer live diagnostics" read. Per-surface verdict after
reading each consumer (2026-06-12) — the audit's flat list was optimistic; only the surfaces that
consume just message/rule/severity/line/file are clean swaps. The live model is phase #1a (no
per-rule metadata, timestamp always "now", never stale), so metadata- and freshness-coupled
surfaces are NOT simple swaps.

- [codeLensProvider.ts](../extension/src/codeLensProvider.ts) — **MIGRATED 2026-06-12.** Per-file
  count now live; refreshed on the debounced `onDidChangeDiagnostics` tick. (The `(N critical)`
  suffix was already dead under the batch source — `readViolations` normalizes `critical → error`
  — so nothing was lost.)
- inline annotations ([inlineAnnotations.ts](../extension/src/inlineAnnotations.ts)) —
  **MIGRATED 2026-06-12.** End-of-line text now matches the squiggles exactly; cache invalidated on
  the same debounced tick.
- [issuesViewCommands.ts](../extension/src/commands/issuesViewCommands.ts) — **BLOCKED on phase #1b.**
  Its two `readViolations` callers consume `byRuleType` / `byRuleStatus` / `ruleMetadataByRule`
  (rule-metadata filters + security-hotspot review). The live model carries none of these; swapping
  would empty the filters and break hotspot review. Migrate only after the bundled rule catalog
  (phase #1b) lands.
- [configSuggestions.ts](../extension/src/config/configSuggestions.ts) — **NOT APPLICABLE.** Reads
  pubspec + analysis_options, never `violations.json`. Audit listed it imprecisely.
- triage dashboard ([triageDashboardHtml.ts](../extension/src/views/triageDashboardHtml.ts)) —
  **NOT A TARGET (by design).** Its job is to report the batch export's *freshness*
  (stale / missing / no-per-rule / run-analysis). Live diagnostics are never stale, so migrating
  would delete the surface's reason to exist.
- rule-packs panel ([rulePacksWebviewProvider.ts](../extension/src/rulePacks/rulePacksWebviewProvider.ts)) —
  **NOT A CLEAN SWAP.** Uses the export *timestamp* ("analysis last run at…") and a disabled-rule
  suppressions snapshot. Live's timestamp is always "now", which would mislabel the run age.

**Remaining actionable work here:** only issuesViewCommands, and only once phase #1b adds the
bundled rule catalog to the live model. The other four are intentionally batch-bound or N/A.

## 3. Supplementary analyzer-lints dashboard pill **[CLOSED — obsolete 2026-06-12]**

Source: `DASHBOARD_SUPPLEMENTARY_COUNTS.md` (2026-05-13). The pills were **not absent-and-pending —
they were deliberately removed**. The 13.13.0 CHANGELOG "Removed (Extension)" entry records that
the "show other analyzer findings" and "show analyzer TODOs" toggles (settings + commands) were
deleted once the Findings Dashboard became holistic: those diagnostics now appear directly in the
main findings list, so the separate opt-in pills were redundant. The TODO/HACK workspace scan
([todosAndHacksTree.ts](../extension/src/views/todosAndHacksTree.ts)) remains as its own tree.

No work — building the pill would re-introduce the redundancy 13.13.0 removed.

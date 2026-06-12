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
- [issuesViewCommands.ts](../extension/src/commands/issuesViewCommands.ts) — **MIGRATED 2026-06-12.**
  The bundled rule catalog (phase #1b) now ships: `bin/generate_rule_catalog.dart` emits
  `extension/media/rules_catalog.json` from `allSaropaRules`, `ruleCatalog.ts` loads it, and
  `applyRuleCatalog` enriches the live model with `ruleMetadataByRule` / `byRuleType` / `byRuleStatus`.
  The two callers are now injected with `readLiveViolations`, so the rule-type/status filters and
  security-hotspot review work off live findings. See the Finish Report below.
- [configSuggestions.ts](../extension/src/config/configSuggestions.ts) — **NOT APPLICABLE.** Reads
  pubspec + analysis_options, never `violations.json`. Audit listed it imprecisely.
- triage dashboard ([triageDashboardHtml.ts](../extension/src/views/triageDashboardHtml.ts)) —
  **NOT A TARGET (by design).** Its job is to report the batch export's *freshness*
  (stale / missing / no-per-rule / run-analysis). Live diagnostics are never stale, so migrating
  would delete the surface's reason to exist.
- rule-packs panel ([rulePacksWebviewProvider.ts](../extension/src/rulePacks/rulePacksWebviewProvider.ts)) —
  **NOT A CLEAN SWAP.** Uses the export *timestamp* ("analysis last run at…") and a disabled-rule
  suppressions snapshot. Live's timestamp is always "now", which would mislabel the run age.

**Remaining actionable work here:** none for §2 — issuesViewCommands shipped, the other four are
intentionally batch-bound or N/A. The plan stays active for the §1.1 visual-render verification.

## 3. Supplementary analyzer-lints dashboard pill **[CLOSED — obsolete 2026-06-12]**

Source: `DASHBOARD_SUPPLEMENTARY_COUNTS.md` (2026-05-13). The pills were **not absent-and-pending —
they were deliberately removed**. The 13.13.0 CHANGELOG "Removed (Extension)" entry records that
the "show other analyzer findings" and "show analyzer TODOs" toggles (settings + commands) were
deleted once the Findings Dashboard became holistic: those diagnostics now appear directly in the
main findings list, so the separate opt-in pills were redundant. The TODO/HACK workspace scan
([todosAndHacksTree.ts](../extension/src/views/todosAndHacksTree.ts)) remains as its own tree.

No work — building the pill would re-introduce the redundancy 13.13.0 removed.

---

## Finish Report (2026-06-12)

### Rule-details catalog — unblocks live metadata filters + hotspot review

Live analyzer diagnostics carry only file, line, rule name, severity, and message — no per-rule
type, lifecycle status, or security-review flag. Two Issues-panel actions need that metadata: the
"filter by rule type/status" command and the security-hotspot review. They previously read the
batch `violations.json` export, which goes stale between analysis runs, so the surfaces that had
already moved to live diagnostics (status bar, Issues tree, dashboard, code lens, annotations)
could not include these two without losing their metadata. A bundled catalog of every rule's
metadata closes that gap.

#### What was built

- **`ViolationExporter.buildRuleMetadataCatalog(rules)`** (lib/src/report/violation_export.dart) —
  a public builder that reuses the existing private `_RuleMetadataSnapshot.fromRule` so the catalog
  is byte-identical to what an analysis export emits per rule (single source of truth; the two can
  never drift).
- **`bin/generate_rule_catalog.dart`** — a generator that walks `allSaropaRules` and writes
  `extension/media/rules_catalog.json` (2314 rules). Run with
  `dart run saropa_lints:generate_rule_catalog`.
- **`extension/src/ruleCatalog.ts`** — loads the bundled catalog once at activation
  (`initRuleCatalog`), caches it, and degrades to an empty catalog on a missing/malformed file so
  activation never fails.
- **`applyRuleCatalog(data, catalog)`** (extension/src/liveDiagnosticsModel.ts) — a separate pure
  enrichment step that attaches `ruleMetadataByRule` for rules present in the model and issue-weights
  `byRuleType` / `byRuleStatus`, with the same `unspecified` / `ready` defaults the export uses.
  Kept separate from the diagnostic-to-violation builder so that builder and its many callers/tests
  stay catalog-agnostic.
- **`readLiveViolations`** (extension/src/liveViolationsData.ts) applies the catalog by default;
  `issuesViewCommands` is now injected with `readLiveViolations`, so both metadata-driven handlers
  read live findings.
- **Publish wiring** — `regenerate_rule_catalog` in scripts/modules/_extension_publish.py
  regenerates the catalog before the extension is compiled into the `.vsix`, so a rule added or
  retuned since the last manual run never ships a stale catalog (non-fatal: ships the committed
  catalog on a tooling failure).

#### Verification

- Extension suite: 1240 passing (10 new — `applyRuleCatalog` ×4 covering present/missing-rule
  bucketing, issue-weighting, and empty-catalog passthrough; `ruleCatalog` loader ×6 covering load,
  cache, and the missing/malformed/no-rules degrade paths). The 11 failures are pre-existing and
  unrelated (cross-file commands, language picker), confirmed identical on the prior commit.
- Dart `test/report/violation_export_test.dart`: 32 passing, including 2 new cases pinning that the
  catalog covers every rule with a well-formed record and that security-hotspot rules carry
  `requiresReview`.
- `npm run check-types` clean; `dart analyze` clean on the changed Dart files.

#### Scope note

The live model remains phase #1a for the freshness-coupled surfaces (triage dashboard, rule-packs
panel) and the not-applicable one (configSuggestions) — those are intentionally not migrated, per
§2 above. This task closed only the issuesViewCommands sub-item; the plan stays active for the
§1.1 consolidated-webview visual-render verification.

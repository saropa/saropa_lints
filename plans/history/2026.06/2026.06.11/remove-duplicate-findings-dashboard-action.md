# Remove duplicate "Open Findings Dashboard" from sidebar Actions panel

The Saropa Lints activity-bar sidebar surfaced the findings dashboard twice — once as "Findings Dashboard" in the Dashboards section and again as "Open Findings Dashboard" in the Actions panel, both with the same `Editor tab · filters · JSON` subtitle. This change removes the duplicate "Open Findings Dashboard" row from the Actions panel.

## Finish Report (2026-06-11)

### Scope
(B) VS Code extension — TypeScript sidebar view + its test, plus the root CHANGELOG. No Dart lint-rule code touched.

### Deep Review
- **Logic & Safety**: Pure deletion of one `LeafItem` from `buildActionItems()`. No control flow, async, or recursion involved.
- **Architecture**: The findings dashboard remains reachable from the Dashboards section row (`saropaLints.openViolationsWideReport`). The removed Actions row targeted `saropaLints.revealFindingsDashboard`; that command is still registered and reachable via the command palette — only the redundant sidebar row was dropped.
- **Linter-Specific Integrity**: N/A (extension UI, not a lint rule).
- **Performance / UX**: One fewer redundant row; no behavior regression.
- **Docs**: CHANGELOG updated under Fixed (Extension).

### Testing
- **Audit**: Grepped `extension/**/*.test.ts` for `revealFindingsDashboard`, `Open Findings Dashboard`, `buildActionItems`, `Findings Dashboard`. Matches:
  - `overviewTreeFlat.test.ts:173` pins `Findings Dashboard` in the Dashboards section — KEPT, not affected.
  - `relatedRuleTelemetryHtml.test.ts:70` pins `Open Findings Dashboard` in the related-rule telemetry **webview HTML** — a different view, not the sidebar; not affected.
- **New test**: Added `Actions section does not duplicate the findings dashboard` to `overviewTreeFlat.test.ts`, mirroring the existing composite-scaffold-absence guard. It asserts no Actions-panel leaf carries the `saropaLints.revealFindingsDashboard` command.
- **Run**: `npx tsc -p tsconfig.test.json` then `mocha out-test/test/views/overviewTreeFlat.test.js` → **11 passing**, including the new test.

### l10n
The removed row used English literals passed positionally to `LeafItem` (a pre-existing pattern across the whole sidebar builder — not localized through `l10n()` today). The change only deletes a row; it adds no new user-facing string and edits no `en.json` key, so no catalog regeneration is required.

### Project Maintenance
- CHANGELOG.md: entry added under `## [Unreleased]` → Fixed (Extension).
- README verified — no rule/doc counts changed.
- Roadmap: not applicable (no lint rule).
- No bug archive — task did not close a `bugs/*.md` file.

### Files changed
- `extension/src/views/sectionedSidebar.ts` — removed the `Open Findings Dashboard` `LeafItem` from `buildActionItems()`.
- `extension/src/test/views/overviewTreeFlat.test.ts` — added regression test pinning the duplicate's absence.
- `CHANGELOG.md` — Fixed (Extension) entry.
- `plans/history/2026.06/2026.06.11/remove-duplicate-findings-dashboard-action.md` — this report.

### Outstanding
None.

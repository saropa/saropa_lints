# Merge Full Audit into the Findings Dashboard

The sidebar's "Full Audit" entry point ran a VS Code quick-pick (workspace-folder
picker, then a scope picker: full project / changed-vs-main / changed-vs-branch /
compare-to-baseline) and, on completion, opened a second, unrelated webview panel
with its own filtering and table — structurally disconnected from the Findings
Dashboard, which already showed the same kind of data sourced from live
diagnostics. Two panels, two filter systems, and a menu-driven entry point for a
workflow that belonged in one place.

## Change

- Removed the sidebar "Full Audit" row, the `saropaLints.fullAudit` command
  (its scope quick-pick, its `view/title` icon, its command-catalog entry).
- Added a "Source" scope selector to the Findings Dashboard toolbar (Live
  diagnostics / Full project / Changed vs main / Changed vs branch…, with an
  inline branch-name field, a Run audit button, a Cancel button, and an
  in-panel progress/status strip).
- Extracted the CLI-spawning logic (`dart run saropa_lints audit`, stderr
  progress-line parsing, cross-platform tree-kill) out of `audit-command.ts`
  into a new shared `extension/src/audit/auditCliRunner.ts`, along with a new
  `auditPayloadToViolationsData()` converter that maps the audit CLI's
  `{ diagnostics: [...] }` payload onto the same `Violation[]` shape
  `liveDiagnosticsModel.ts` already produces for live findings — so a
  non-live audit's results flow through the dashboard's existing
  filter/group/table/export pipeline with no audit-specific branching there.
- `violationsWideReportView.ts` gained `auditScopeState`/`auditResult`/
  `auditCts` module state, a `runAuditForDashboard()` function, and
  `setAuditScope`/`cancelAudit` message handlers. `rebuildDashboardHtml`
  now sources `raw` from either live diagnostics or the cached audit result
  depending on `auditScopeState.mode`.
- The explorer right-click "Audit Folder..." command (`auditFolder`) is
  unchanged — it stays a folder-scoped, no-decision workflow with its own
  lightweight report panel (`audit-report-panel.ts` and siblings), which is a
  different use case from the workspace-wide scope picker that was removed.
- Fixed a pre-existing invalid trailing comma in `en.json`
  (`dashboards.controls`) discovered while validating the file — would have
  broken the whole i18n runtime at load time. Not otherwise related to this
  change; left in the same commit since it blocks JSON parsing entirely.
- Removed now-dead i18n keys (`audit.scope.*`, `audit.pickWorkspaceFolder`)
  that only the deleted quick-pick referenced.

## Review fixes applied

- Cancelling an in-flight dashboard-triggered audit previously discarded the
  cancellation message, so the toolbar fell through to a "Not run yet"
  status instead of confirming the cancel — `runAuditForDashboard` now keeps
  the cancel message in `auditScopeState.error` the same as any other
  failure.
- Each dashboard-triggered audit run allocated a
  `vscode.CancellationTokenSource` that was never disposed (VS Code disposes
  the one it hands out via `withProgress` itself; this path owns its own).
  `runAuditForDashboard` now calls `cts.dispose()` once the run settles.

## Follow-up hardening (same day)

After the initial merge, a second review pass (prompted by the finish
checklist's reflection gate) applied three more fixes:

- **Legacy impact normalization.** `spawnAuditCli` runs the SCANNED
  PROJECT's own pinned `saropa_lints`, not necessarily the version bundled
  with this extension — a project still pinned below 13.4.x can emit the
  legacy 5-bucket `impact` vocabulary (critical/high/medium/low/opinionated).
  `auditPayloadToViolationsData()` did not normalize this the way
  `readViolations()` already does for the batch `violations.json` export
  (see `normalizeLegacyImpact`'s doc comment, issue #208's "401 findings / 0
  shown" regression) — an old project's audit run would have silently shown
  zero rows under the dashboard's default `{error, warning, info}` filter.
  Fixed by routing `impact` through the same `normalizeLegacyImpact()`.
- **Persisted audit scope.** The toolbar's Source selection (mode + ref) now
  persists to `context.workspaceState` under
  `saropa.findingsDashboard.auditScope` and rehydrates on the next fresh
  panel open — only the selection is persisted, never the CLI result; a
  non-live hydrate re-runs the audit CLI immediately rather than trying to
  resurrect a stale result. `openViolationsWideReport()` only hydrates when
  `currentPanel` is `undefined` (a genuinely fresh panel), so an
  already-open panel's in-session choice is never clobbered by a stale
  workspace-state read.
- **Cancel-on-live-switch.** A second `/code-review low` pass on this
  follow-up diff caught a real bug it introduced surface: switching the
  Source dropdown back to "Live diagnostics" while a non-live audit CLI run
  was still in flight did not cancel it — the orphaned `dart` process kept
  running with no UI left to cancel it, and its eventual completion would
  have silently overwritten whatever the user had moved on to. Fixed by
  calling `auditCts?.cancel()` in the `setAuditScope` handler's
  `mode === 'live'` branch, mirroring what the panel's `onDidDispose` already
  did on close.

## Known gap — not addressed

Baseline-compare mode (`--baseline`, "Save as baseline") is not part of the
new toolbar scope selector — it was a secondary capability, deliberately cut
to keep this change scoped. The "Save as baseline" button still exists in
the kept `auditFolder` report panel, but nothing feeds `useBaseline: true`
into any audit run any more, so it is now an orphaned control (writes a
baseline file nothing reads back). Flagged for a follow-up decision: wire it
back in on the folder-audit path, or remove the button.

## Verification

- `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json --noEmit`: clean
  for every file this change touched.
- `mocha "out-test/test/views/**/*.test.js" "out-test/test/audit/**/*.test.js"`:
  317 passing, including the relocated `killAuditProcessTree` test (its
  import was repointed from `audit-command.ts` to the new
  `auditCliRunner.ts`).
- Not verified visually — no Extension Development Host was launched from
  this environment. See the handoff's manual-test list.

## Unrelated concurrent work observed

Over the course of this change, `extension/src/audit/audit-report-html.ts`,
`audit-report-panel.ts`, `audit-report-script.ts`, `audit-report-styles.ts`,
and `extension/src/extension.ts` were seen changing on disk under a
different, unrelated in-progress edit (an "Export JSON" / hide-INFO-by-default
feature for the still-kept folder-audit report panel). At the time this
change was finished, `audit-report-html.ts` had a live compile error
(`hasErrorsOrWarnings` used before its declaration) from that concurrent
edit — not caused by, or fixed by, this change. Left untouched deliberately
since it is someone else's in-progress work; the whole-project `tsc` will
not go green until that edit finishes.

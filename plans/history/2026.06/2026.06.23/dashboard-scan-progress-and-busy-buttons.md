# Package Dashboard scan-progress + pane busy buttons

The Package Dashboard's "Rescan" button launched a multi-minute scan whose only
feedback was a VS Code notification toast, leaving the dashboard on stale data
with no in-panel signal — the panel read as frozen. The detail pane's "Upgrade"
and "Retry" buttons had the same gap: each kicks off slow work (`pub get` + the
full test suite, or network re-fetches) yet gave no in-pane busy indication.

## Finish Report (2026-06-23)

### Defect

A long-running action triggered from a webview gave no progress feedback inside
that webview. Three buttons were affected on the Package Dashboard surface:

1. **Rescan** (toolbar) — ran the package scan with feedback only via a
   `vscode.window.withProgress` notification. The dashboard kept showing the
   previous results until the scan finished and the panel HTML was rebuilt, so a
   user clicking Rescan saw no change and concluded the refresh was broken.
2. **Upgrade** (detail pane) — invoked `updateFromCodeLens`, which runs
   `flutter pub get` followed by the full test suite (minutes). The pane button
   neither disabled nor relabelled; feedback was limited to the output channel
   and a toast.
3. **Retry** (detail pane partial-fetch banner) — re-ran failed pub.dev/GitHub
   fetches with no explicit busy signal on the button itself.

### Resolution

**Live scan-progress bar.** A determinate progress bar was added under the
dashboard header (`report-html.ts`), hidden by default and styled in
`report-styles.ts`. `scanPackages` already reports a per-package increment of
`100 / deps.length`, so a host-side wrapper (`withPanelProgress` in
`extension-activation.ts`) accumulates those increments into a 0..100 percentage
and forwards each report to the open panel. `runScan` posts a `scanStarted`
lifecycle message after the coalesce/abort early-returns and a `scanFinished`
message in its `finally` (the kill-switch for the cancel/abort path, where no
panel rebuild occurs). `VibrancyReportPanel` gained static
`postScanStarted/postScanProgress/postScanFinished` methods that no-op when the
panel is closed. The webview's message listener (`report-script.ts`) shows an
indeterminate sweep on `scanStarted`, switches to a determinate fill + phase
label + percent on `scanProgress`, and hides the bar on `scanFinished`. The bar
also animates for file-watcher and silent background refreshes when the panel is
open, since those run through the same `runScan` path.

**Pane action busy state.** The detail pane's post callback was generalized from
an HTML-only signature to a generic message poster so the controller can emit
`paneAction` status messages on the same channel
(`package-detail-pane-controller.ts`, `report-webview.ts`). The controller wraps
the upgrade command in `paneAction` busy/done messages, with `done` in a
`finally` so a failed or rolled-back upgrade (which triggers no dashboard
rebuild) still re-enables the button. Client-side, the report script sets an
optimistic busy state on click — disabling the button, adding a spinner, and
swapping in a localized `data-busy-label` ("Upgrading…" / "Retrying…") — and the
host-driven `paneAction` message reconciles the final state. Busy labels are
server-rendered as `data-busy-label` attributes so no English copy is hardcoded
in the static webview script. The spinner respects `prefers-reduced-motion`.

### Scope and constraints

- Webview script edits are validated by resolving the generated template literal
  and executing it against DOM stubs; the strict nonce CSP permits the
  determinate fill width because it is set via CSSOM (`element.style.width`), not
  an inline style attribute.
- Four user-facing strings were added to `en.json`. The translated locale
  catalogs (24 non-English locales) are stale until the translation pipeline is
  regenerated; the publish coverage gate blocks release until then.

### Verification

- `tsc --noEmit` clean for both `tsconfig.json` and `tsconfig.test.json`.
- Generated report webview script: syntax-valid and runs to completion against
  DOM stubs.
- esbuild bundle rebuilt clean; new wiring (`scanStarted`, `scanProgress`,
  `paneAction`, `btn-busy`, `data-busy-label`) present in `dist/extension.js`.
- Affected mocha suites (`package-detail-html`, `report-html`, `report-webview`):
  168 passing, including new assertions pinning the scan-progress element and the
  `data-busy-label` contract on the Upgrade and Retry buttons.

### Audit outcome (other dashboards)

A sweep of every webview button that launches scans/refreshes/process work found
the rest already covered: Code Health (streaming progress + pause/resume/cancel),
Findings (analysis-progress box + disabled buttons), the Saropa Dashboards
launchpad (instant shell + per-pane placeholders/retry), the Consolidated
dashboard (diagnostic-driven auto-refresh, no slow button), Related Rule
Telemetry (instant in-memory re-render), and Project Map (no in-webview rescan
button; scan is command-only).

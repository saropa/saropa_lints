# Findings Dashboard header flicker

The Findings Dashboard reassigned its entire `panel.webview.html` on every diagnostic
change so it could stay in sync with the Problems panel. Because a full `webview.html`
reassignment reloads the document, the header's CSS entrance animation (`hero-in`, an
opacity-and-slide fade) replayed on every reload. VS Code fires `onDidChangeDiagnostics`
even when the published diagnostic set is unchanged, and a live-analyzing Dart/`custom_lint`
workspace republishes frequently, so the header strobed continuously. The fix stops the
reload when nothing the user can see has changed, and restricts the entrance animation to
the first paint of a panel.

## Finish Report (2026-06-15)

### Scope
(B) VS Code extension — TypeScript and webview CSS only. No Dart lint rules, analyzer
plugin code, `tiers.dart`, or `example/` fixtures were touched.

### Problem
The live-diagnostics refresh path (`rebuildDashboardHtml` in
`extension/src/views/violationsWideReportView.ts`) unconditionally rebuilt the full HTML
and assigned it to `panel.webview.html` on each debounced diagnostic change. Two
consequences:
1. Every assignment reloaded the webview document, replaying `.dash-hero { animation: hero-in }`
   — the visible header flicker.
2. The reload happened even when the rendered findings, grade, counts, and filter state were
   byte-for-byte identical, because `onDidChangeDiagnostics` fires on no-op republishes.

### Change summary
- **No-op guard (`violationsWideReportView.ts`).** `rebuildDashboardHtml` now builds the
  renderer input once, then computes a signature via
  `JSON.stringify({ ...input, reportTimestamp: '', firstPaint: false })` and compares it to
  the last painted signature. On a match it skips the `webview.html` reassignment entirely
  and returns, so the document does not reload. The scan timestamp is neutralized because
  `buildViolationsDataFromDiagnostics` stamps a fresh `new Date().toISOString()` on every
  build; the CSP nonce is generated inside the renderer (not an input field), so it never
  pollutes the comparison. Module-level `lastFindingsRenderSignature` and `hasPaintedOnce`
  hold the state and are reset in the panel's `onDidDispose`, so a reopened panel — whose
  fresh webview has no DOM — always paints rather than matching a stale signature and
  rendering blank.
- **Gauge-pending correctness (`violationsWideReportView.ts`).** The live listener posts
  `gaugePending: true` on each diagnostic change to dim the health gauge while analysis is
  in flight, and previously relied on the fresh HTML to ship the settled, un-dimmed gauge.
  With reloads now skipped, the no-op branch explicitly posts `gaugePending: false` so the
  gauge cannot stay dimmed after an identical republish.
- **First-paint-only entrance animation.** A `firstPaint?: boolean` field was added to
  `ViolationsDashboardHtmlInput` (`violations-dashboard-shared.ts`). When `false`, the
  renderer (`violationsDashboardHtml.ts`) emits `<body data-no-hero-anim>`, and a new CSS
  rule `body[data-no-hero-anim] .dash-hero { animation: none; }` (`violationsDashboardStyles.ts`)
  suppresses the entrance animation. The field is optional and defaults to animating, so the
  first paint of a panel (and every standalone caller / UX-page generator / test that omits
  it) keeps the entrance animation. The host passes `firstPaint: !hasPaintedOnce`, so only a
  genuine content change after the first paint repaints — and it does so without re-animating.

### Why this is the correct fix, not a workaround
The consolidated dashboard (`consolidated/consolidatedView.ts`) and the global diagnostics
refresh (`extension.ts`) already avoid full reloads — the former sets HTML once and patches
the DOM via `postMessage`, the latter only refreshes trees/status without touching any
webview. The Findings Dashboard was the lone surface still doing a full reload on live
updates: an incomplete migration when dashboards moved to live-diagnostics refresh, not a
broad regression. The signature guard removes the reload in the dominant case (identical
republish), and the first-paint gate removes the residual flicker on genuine rapid changes,
without rewriting the dashboard to patch-in-place.

### Files changed
- `extension/src/views/violationsWideReportView.ts` — signature guard, dispose reset,
  gauge-pending clear in the no-op branch, `firstPaint` plumbed into the render input.
- `extension/src/views/violationsDashboardHtml.ts` — emit `data-no-hero-anim` on `<body>`
  when `firstPaint === false`.
- `extension/src/views/violationsDashboardStyles.ts` — `body[data-no-hero-anim] .dash-hero`
  animation suppression rule.
- `extension/src/views/violations-dashboard-shared.ts` — optional `firstPaint` on
  `ViolationsDashboardHtmlInput`.
- `extension/src/test/views/violationsDashboardHtml.test.ts` — test pinning first-paint vs
  live-rebuild animation behavior.
- `CHANGELOG.md` — `[Unreleased] → Fixed (Extension)` entry.

### Verification
- `tsc --noEmit -p ./` (whole-project type check): exit 0.
- `tsc -p tsconfig.test.json`: exit 0.
- `mocha out-test/test/views/violationsDashboardHtml.test.js`: 31 passing, including the new
  first-paint/live-rebuild assertion.
- Direct render check: `firstPaint:true` → no `data-no-hero-anim`; `firstPaint:false` →
  attribute present; omitted → no attribute (backward-compatible default).

### Localization
No user-facing strings were added or changed. `data-no-hero-anim` is a CSS data-attribute
hook (exempt), and no `en.json` keys were touched, so no catalog regeneration was required.

### Outstanding
The signature-guard host path (`rebuildDashboardHtml`) is exercised indirectly; a direct
unit test would require mocking the VS Code webview panel and the live-diagnostics listener.
The render-side first-paint behavior — the part that visibly suppresses the flicker — is
covered by the new test.

# Findings dashboard — clickable, self-ticking freshness stamp

The editor-area Findings dashboard renders from live analyzer diagnostics, but its
host-side rebuild listener early-returns while the panel is hidden. A dashboard left
open in a background tab therefore kept the relative "freshness" label frozen at the
value it held on its last paint (typically "just now"), and offered no in-panel way to
pull the analyzer's current findings. The label was also worded "Last run", implying a
separate analysis pass, when the underlying timestamp is the moment the panel last
repainted from diagnostics.

## Finish Report (2026-06-12)

### Scope

(B) VS Code extension (TypeScript webview) plus (C) the `en.json` source catalog and
CHANGELOG. No Dart lint-rule / analyzer code was touched.

### What changed

The status-line freshness pill in the Findings dashboard became an interactive,
self-updating control:

- **Clickable refresh.** The pill renders with `role="button"`, `tabindex="0"`, and
  `data-action="refresh"`. Click, Enter, or Space post the existing `{type:'refresh'}`
  message — the same one the More-menu "Reload from disk" item fires — which re-reads
  the analyzer's current diagnostics and repaints. No analysis run is triggered.
- **Self-ticking age.** The pill carries the localized relative-time templates as data
  attributes (`data-t-justnow` / `data-t-min` / `data-t-hr` / `data-t-day`), each with a
  literal `{n}` placeholder produced by passing `{ min: '{n}' }` (etc.) to `l10n()`. A
  webview ticker recomputes the label every 30s and on `visibilitychange` / window
  `focus`, substituting `{n}`. The client buckets mirror the server `formatRelative`
  buckets exactly (just-now < 45s, minutes < 60m, hours < 24h, else days), so the ticked
  label can never disagree with the server-rendered one.
- **Relabel.** The prefix changed from "Last run" to "Updated" (new key
  `findingsDash.status.updatedPrefix`) because the timestamp is repaint time, not a
  distinct analysis pass. A tooltip key `findingsDash.status.refreshHint` ("Click to
  refresh from the analyzer") advertises the new affordance.

### Files changed

- `extension/src/views/violations-dashboard-top.ts` — `buildStatusLine` emits the
  interactive pill, the `freshness-rel` span, and the template/`data-updated-at` attrs.
- `extension/src/views/violations-dashboard-script.ts` — `tickFreshness` re-ages the
  label on an interval + on refocus; a delegated handler fires `{type:'refresh'}` on
  click/Enter/Space for any `[data-action="refresh"]` element.
- `extension/src/views/violationsDashboardStyles.ts` — `.status-line .pill.freshness`
  pointer cursor, hover tint, and `:focus-visible` ring. (Styles live in this
  stylesheet, not `dashboardChromeStyles.ts`, which the Findings dashboard does not
  load.)
- `extension/src/i18n/locales/en.json` — added `findingsDash.status.updatedPrefix` and
  `findingsDash.status.refreshHint`.
- `extension/src/test/views/violationsDashboardHtml.test.ts` — the test that pinned the
  old "Last run" literal now pins the "Updated" label, the `data-action="refresh"`
  affordance, the `freshness-rel` span, and `data-updated-at`.
- `CHANGELOG.md` — `### Changed (Extension)` bullet under `[13.12.6]`.

### Verification

- `tsc --noEmit -p tsconfig.json` — clean.
- `tsc -p tsconfig.test.json` then mocha on `out-test/test/views/violationsDashboardHtml.test.js`
  — 30 passing (was 29 passing / 1 failing on the stale "Last run" assertion before the
  test was updated).
- Test-symbol audit: grep of `extension/src/test` for `Last run`, `lastRunPrefix`,
  `freshness`, `data-action`, `updatedPrefix`, `refreshHint`, `tickFreshness` surfaced
  no other assertions pinning the changed behavior.

### Localization status

Two source keys were added to `en.json`. The translated locale catalogs
(`*.<lang>.json`) are now stale for those two keys and fall back to English at runtime
via `l10n()`. The catalog regeneration script (`extension/scripts/generate_translations.py`)
is the NLLB machine-translation pipeline and was deliberately NOT run — running it is a
standing hard prohibition. Backfilling the two translations is left to that pipeline's
own cadence; no user-facing English literal was hardcoded (both strings route through
`l10n()` keys).

### Notes for the reviewer

- The host already exposed `{type:'refresh'}` and only re-reads in-memory diagnostics
  (zero analysis cost), so the new affordance reuses existing, cheap plumbing.
- The background-tab gap is narrowed but not eliminated by design: while hidden the
  panel still does not auto-repaint its data (host listener early-returns on
  `!panel.visible`); the ticker keeps the *age* honest and the click lets the user pull
  fresh data on demand. Auto-refreshing data on refocus was intentionally not added to
  avoid surprise re-renders.

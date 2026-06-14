# Plan: Package Vibrancy Report — Remaining Hardening

> **Origin:** The Package Vibrancy report hardening effort
> (`extension/src/vibrancy/`) shipped 17 of 19 acceptance checks. The completed
> work and its full audit live in the archived parent plan:
> `plans/history/2026.06/2026.06.14/PACKAGE_VIBRANCY_REPORT_HARDENING.md`.
> This plan tracks only the two items that were still open when the parent was
> archived (2026-06-14).

## Status (2026-06-14): COMPLETE

Both items below are now implemented and verified. This plan is ready to
archive — all 19 acceptance checks of the parent hardening effort are met.

- **WS5 — DONE.** `computePublishedAgeMonths` is exported with an injectable
  reference date; six tests in `report-html.test.ts` pin the month math against
  the real `device_calendar 4.3.3` publish date (2024-09-29).
- **WS6 — DONE.** The dependency graph opens collapsed at depth 1 (direct deps
  only) with an Expand toggle, and supports drag-pan, button/wheel zoom, reset,
  and focus-on-click, all driven by the SVG viewBox.

## Open items (resolved)

### 1) WS5 — published-age regression fixture (DONE)

The age calculation is UTC/month-aware and correct
(`extension/src/vibrancy/views/report-html.ts`, the published-age branch around
lines 1397-1410). What is missing is a test fixture that pins a known package's
reported age so a future edit to the age math is caught.

- Add a test asserting `device_calendar 4.3.3`'s reported age falls in the
  expected range, using a fixed reference date so the assertion is deterministic
  (the age math must be timezone-neutral and month-aware, not naive day/365).
- The `device_calendar` files currently in the repo are lint-rule fixtures,
  unrelated to vibrancy age math — do not reuse them; build a vibrancy result
  fixture instead.

Acceptance check (from the parent plan, WS5):

- Known example (`device_calendar 4.3.3`) reports the expected age range.

### 2) WS6 — graph zoom / pan / focus (DONE)

The dependency network diagram is scroll-only
(`extension/src/vibrancy/views/report-styles.ts:922`,
`max-height:420px; overflow:auto`). It has no zoom, pan, or focus-selected
control.

- Add basic graph controls: zoom, pan, and focus-on-selected-package.
- Start with the lightweight local SVG renderer already in use (the
  `renderNetwork` function in `report-script.ts`); no heavy graphing dependency.
- Keep the table as the source of truth — the graph already mirrors the table's
  filters as of 2026-06-14 (the filter-sync item is done), so zoom/pan must not
  regress that behavior.
- **Default depth: start collapsed at depth = 1** (direct dependencies only;
  decided 2026-06-14). Transitives expand on focus/zoom rather than rendering
  the full closure up front — keeps the initial diagram readable on large
  projects and bounds first-render cost.

Acceptance checks (from the parent plan, WS6):

- Large graphs remain usable (no blocking freeze for a typical project size).
- Zoom / pan / focus controls work and do not break node-click → table-row
  navigation.

## Decisions

- **Graph default depth: collapsed at depth = 1** (direct dependencies only;
  2026-06-14). Folded into WS6 above.

## Done — for context

The dependency graph now mirrors the table's filters (search, age slider,
dev-deps toggle, presets, chart filter). See the archived parent plan's
`## Finish Report (2026-06-14)` for the filter-sync implementation and
verification.

---

## Finish Report (2026-06-14)

### Scope

VS Code extension webview (`extension/src/vibrancy/views/`). No Dart lint-rule,
analyzer, or `example/` change. Closes both remaining items of the Package
Vibrancy report hardening effort — all 19 acceptance checks of the parent plan
are now met.

### WS6 — graph zoom, pan, focus, and collapsed-at-depth-1 default

The dependency network diagram previously rendered the full bipartite graph
(direct dependencies in a left column, every unique transitive in a right
column, edges between) at natural pixel size inside a scroll-only container,
with no zoom, pan, or focus control. On a large project the diagram opened as a
wall of overlapping labels that could only be scrolled.

The renderer in `report-script.ts` was reworked around the SVG `viewBox`:

- Two pure builders were extracted — `buildNetworkLayout` (produces the inner
  SVG markup, the natural canvas size, and a name→point map for focus) and
  `buildNetworkToolbar` (the control bar markup).
- The graph now defaults to collapsed at depth 1: only the direct-dependency
  column is drawn (no transitive column, no edges), so a large graph opens
  readable. An "Expand transitives (N)" / "Collapse to direct deps" toggle
  flips a script-scope `networkExpanded` flag and re-renders; the flag lives
  outside the render function so a filter-driven re-render preserves the user's
  choice.
- Zoom and pan are driven entirely by the `viewBox` with
  `preserveAspectRatio="xMidYMid meet"`, which scales the content uniformly and
  avoids the axis-squash the old natural-pixel layout was guarding against.
  Zoom is available via toolbar buttons (center-anchored) and the mouse wheel
  (cursor-anchored), clamped to 0.2×–4× of the natural size. Pan is a pointer
  drag on empty canvas; a pointerdown that lands on a node or edge is left alone
  so its click still fires (pointer capture would otherwise swallow it). A
  "Reset view" button refits the whole graph, and clicking any node centers it
  before the existing jump-to-table-row navigation runs. The `viewBox` resets
  to fit-all on each render because a filter change alters the node set.

`report-styles.ts` adds the toolbar and theme-aware secondary-button styling,
switches the canvas to a fixed-height pannable surface (`overflow: hidden`,
`touch-action: none`, grab/grabbing cursor) instead of the old scroll model.

### WS5 — published-age regression fixture

`computePublishedAgeMonths` computes the whole-month age of a package's publish
date, UTC and calendar-month aware, with a day-of-month rollback (an age ticks
to the next month only once the day-of-month is reached). It had no test, so a
regression to the naive days/365 calculation it replaced would go uncaught.

The function was exported and given an injectable `now` parameter (defaulting to
`new Date()`, so production behavior is unchanged) to make the month math
pinnable against a fixed reference instant. Six tests in `report-html.test.ts`
assert the behavior against the real pub.dev publish date for
`device_calendar 4.3.3` (2024-09-29, read from the pub.dev API): exact 12 months
at the anniversary, the one-day-early rollback to 11, a year-boundary count, UTC
neutrality across two constructions of the same instant, a zero-clamp at and
before the publish date, and null for missing/unparseable input.

### Verification

- `tsc --noEmit` and `tsc -p tsconfig.test.json`: both clean.
- The generated browser script parses (`new Function`); `buildNetworkLayout` was
  executed directly against sample nodes — collapsed yields directs only (no
  `<line>` edges, narrow canvas), expanded yields the bipartite layout with
  edges and the transitive column.
- `report-html.test.ts` / `report-webview.test.ts` / `detail-view-html.test.ts`:
  192 passing, 0 failing, including the six new age tests and the dep-network
  panel-position test.

### Localization note

The strings added to the network toolbar ("Zoom in/out", "Reset view", "Expand
transitives", "Collapse to direct deps") are hardcoded English, matching the
report client script's existing convention: `getReportScript` produces
browser-side JavaScript as a string and has no access to the `l10n()` runtime,
which executes host-side. The whole script's ~40 user-visible strings are
hardcoded for the same reason. Routing the client script through the catalog is
a separate, larger effort outside this scope; no `en.json` key was added or
changed, so no catalog regeneration was required.

Finish report appended: plans/PACKAGE_VIBRANCY_REPORT_REMAINING.md

# Plan: Package Vibrancy Report — Remaining Hardening

> **Origin:** The Package Vibrancy report hardening effort
> (`extension/src/vibrancy/`) shipped 17 of 19 acceptance checks. The completed
> work and its full audit live in the archived parent plan:
> `plans/history/2026.06/2026.06.14/PACKAGE_VIBRANCY_REPORT_HARDENING.md`.
> This plan tracks only the two items that were still open when the parent was
> archived (2026-06-14).

## Open items

### 1) WS5 — published-age regression fixture (MISSING)

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

### 2) WS6 — graph zoom / pan / focus (PARTIAL)

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

Acceptance checks (from the parent plan, WS6):

- Large graphs remain usable (no blocking freeze for a typical project size).
- Zoom / pan / focus controls work and do not break node-click → table-row
  navigation.

## Open product decisions (carried from the parent plan)

- Should the graph view include all transitives by default, or start collapsed
  at depth = 1? (Affects WS6 zoom/pan defaults.)

## Done — for context

The dependency graph now mirrors the table's filters (search, age slider,
dev-deps toggle, presets, chart filter). See the archived parent plan's
`## Finish Report (2026-06-14)` for the filter-sync implementation and
verification.

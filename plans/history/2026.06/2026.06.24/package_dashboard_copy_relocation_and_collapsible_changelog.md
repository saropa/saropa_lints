# Package Vibrancy detail-pane: copy relocation + collapsible changelog

The Package Vibrancy dashboard carried a per-row "copy as JSON" icon column that
widened an already-dense table, and the package detail panel's changelog rendered
every release between the installed and latest version fully expanded, flooding the
panel on large upgrade gaps. This task removes the per-row copy column in favor of a
single copy button in the docked detail pane header, and makes each changelog version
an independently collapsible block with only the latest expanded by default.

## Finish Report (2026-06-24)

### Scope

VS Code extension only (`extension/src/`, TypeScript webview generation). No Dart lint
rules, analyzer code, tiers, or `analysis_options*.yaml` touched.

### Change 1 — Copy-as-JSON moves from each table row into the detail pane header

Prior state: every package row in the Package Vibrancy dashboard table rendered a
dedicated `col-copy` header cell and a `copy-cell` clipboard button (`.copy-btn`,
`data-pkg`), adding a full column to a 13-plus-column table. The click handler iterated
`document.querySelectorAll('.copy-btn')` and copied `packageData[pkg]` as pretty JSON.

New state:
- The `col-copy` header and per-row `copy-cell` are removed from
  `report-html-table.ts`. The base visible-column count comment and constant were
  corrected from 14 to 13 to reflect the dropped column.
- A single copy button (`#detailPaneCopy`, class `detail-pane-copy`) now sits beside the
  close button inside the detail pane header (`report-html.ts`), wrapped in a new
  `.detail-pane-actions` flex container so the kicker stays left-aligned and the two
  header actions group on the right.
- `openDetailPane(name)` retags the button's `data-pkg` with the package currently shown
  in the pane on every open (`report-script-parts.ts`), so one button always targets the
  open package.
- The former per-row `.copy-btn` loop was replaced by a single delegated-free handler
  bound to `#detailPaneCopy` that reads `data-pkg`, copies `packageData[pkg]`, and shows
  the same checkmark/1.5s-restore feedback. `packageData` is in the same generated-script
  scope, unchanged.
- Styling: the table-oriented `.col-copy` / `.copy-cell` / `.copy-btn` rules were
  replaced with `.detail-pane-copy` rules modeled on `.detail-pane-close` (hover,
  focus-visible outline, `.copied` success color), including the reduced-motion override.
- The button title/aria reuse the existing `packageDashboard.row.copyRowJson` catalog
  key; no new l10n key was required. The now-orphaned `a11y.copyRow` key was left in
  `en.json` (an unused English key is inert and removing it would force a locale regen).

### Change 2 — Changelog versions are individually collapsible, latest expanded

Prior state: `buildChangelogSection` in `package-detail-html.ts` rendered each entry as a
flat `<div class="changelog-entry">` with an always-visible body. Entries arrive
newest-first (filtered to versions greater than current and at most latest, capped at 20).

New state:
- Each entry now renders as a native `<details class="changelog-entry">` with the version
  heading as its `<summary class="changelog-version">`. The first entry (the latest
  version) receives the `open` attribute; all older entries are folded by default.
- Native `<details>` toggling needs no JavaScript and does not collide with the detail
  pane's delegated click handler, which only acts on `.section-header`, `.filter-btn`,
  `.gap-table th[data-col]`, `#retry-fetches`, and `[data-action]` elements — a `<summary>`
  matches none of these.
- Styling (`package-detail-styles.ts`): `.changelog-version` becomes a flex summary with a
  pointer cursor; the browser's default disclosure triangle is suppressed
  (`list-style: none` + `::-webkit-details-marker { display: none }`) and a custom `▸`
  marker that rotates 90° when `[open]` is applied. A reduced-motion override disables the
  marker transition.

### Tests

- `extension/src/test/vibrancy/views/report-html.test.ts`: the two pre-existing copy-column
  assertions were re-pinned to the new behavior — one asserts `#detailPaneCopy` is present
  in the detail pane header, the other asserts no `col-copy` / `copy-cell` column renders.
- `extension/src/test/vibrancy/views/package-detail-html.test.ts`: added a test asserting
  every changelog version is its own `<details class="changelog-entry">` and exactly one —
  the latest — carries the `open` attribute. The existing heading/body/escaping/truncation
  assertions pass unchanged against the `<details>`/`<summary>` structure.
- Verification: `tsc --noEmit` clean. Scoped mocha runs (with the vscode mock registered
  first): `report-html.test.js` — 150 passing; `package-detail-html.test.js` — 13 passing.

### Notes

CHANGELOG `[Unreleased]` carries two `### Changed (Extension)` entries for the relocation
and the collapsible changelog. No rule counts or product facts changed, so README and
ROADMAP were untouched.

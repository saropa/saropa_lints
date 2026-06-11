# Project Map size treemap — illegible folder/file labels

Triggered by a user report (screenshot) of the Saropa Project Map ▸ size map: "contrast issues … headings are white on white or missing." Folder headings rendered invisible in dark mode and the darkest tiles showed unreadable file names. No `bugs/*.md` existed for this; the report was raised in chat.

## Finish Report (2026-06-11)



### Scope

**(A)** Dart — the `project_health` HTML reporter that the extension's Saropa Project Map command renders. Plus docs (CHANGELOG). No extension TypeScript, no lint rules touched.

### Root cause

`lib/src/cli/project_health/health_html_template.dart` builds the treemap's ECharts config as an inline `<script>`. The tile fills always use a fixed orange heat ramp (`RAMP` cream→dark-brown), identical in light and dark page modes. But the label text colors keyed off the page's `prefers-color-scheme`:

- Leaf file labels: hardcoded `color: "#0f172a"` (dark slate) → dark-on-dark, illegible on the hottest brown tiles (`string`, `datetime`).
- Folder `upperLabel` (and the level-1 `upperLabel`): `color: fg`, where `fg` is light `#e2e8f0` in dark mode → light-on-cream, the "white on white / missing" headings the user saw.

A mode-keyed text color cannot work when the background is mode-independent.

### Fix

Derive each label's text color from the tile's own fill luminance, not the page mode:

- Split `rampColor` into `rampRgb` (returns `[r,g,b]`) + `rgbCss` helper.
- Added `contrastText(rgb)`: Rec. 709 luma; returns near-black `#0f172a` above a 0.58 cutoff, near-white `#f8fafc` below — keeps mid-orange tiles legible with dark text.
- `paint()` now returns each node's `[fillRgb, ratio]`. Leaves get a per-node `label.color` from their fill. Folders adopt their hottest descendant's color for the header band (mirrors ECharts' rollup) and set `upperLabel.color` to contrast against that band.
- Per-data-item `label`/`upperLabel` colors override the series-level defaults in ECharts, so the static `#0f172a` / `fg` defaults remain only as harmless fallbacks.

### Verification

- `dart test test/project_health/health_html_reporter_test.dart` → 2 tests pass (structural surfaces; no color assertions to break).
- Test audit: grepped `test/` for `rampColor`, `contrastText`, `upperLabel`, `treemap`, `#0f172a` — only the reporter test references `id="treemap"` structurally; the `rampColor`→`rampRgb` rename breaks no assertion.
- Extracted the generated treemap JS and evaluated it with node on a synthetic tree:
  - hot leaf `string` rgb(194,65,12) → label `#f8fafc` (white) ✓
  - cold leaf `map` rgb(254,243,198) → label `#0f172a` (dark) ✓
  - folder `test` upperLabel adopts hottest leaf rgb(194,65,12) → `#f8fafc` (white) ✓

### Files changed

- `lib/src/cli/project_health/health_html_template.dart` — treemap label-color logic.
- `CHANGELOG.md` — entry under `[Unreleased] → Fixed (Extension)`.
- `plans/history/2026.06/2026.06.11/project_map_size_treemap_label_contrast.md` — this report.

### Outstanding

None. Folder-level cognitive-heat aggregation remains a pre-existing follow-up noted in the file's own comment; unrelated to this contrast fix.

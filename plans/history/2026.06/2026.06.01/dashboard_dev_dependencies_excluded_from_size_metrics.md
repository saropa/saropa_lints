# Package Dashboard — exclude dev_dependencies from Total Size summary and Size Distribution chart

**Status: Fixed**

Created: 2026-06-01
Surface: VS Code extension — Package Dashboard webview (`extension/src/vibrancy/views/`)
Severity: Misleading metric (High — inverts the meaning of the two most prominent size surfaces in the dashboard)

---

## Trigger

User opened the Saropa Package Dashboard against a Flutter project that uses `saropa_lints` as a `dev_dependency`. The dashboard reported:

- **Total Size** card: 13 MB
- **Size Distribution** chart: `saropa_lints` 8.6 MB (66.3%), drift_dev 0.87 MB (6.7%), dart_style 0.78 MB (6.0%), build_runner 0.66 MB (5.1%) — every named segment in the top of the chart was a dev-only build/lint tool.

User pointed out: *"saropa_lints is a dev dependency! it is NOT contributing to apk/package bloat"*. Correct — `dev_dependencies` are compile/lint/test-time tooling; nothing in that section ships to the user's APK / IPA / web bundle. The two surfaces meant to communicate *shipped bytes* were summing in tooling that never reaches a user, and the biggest bar was that tooling.

This is the same class of error fixed in [`plans/history/2026.05/2026.05.13/infra_vibrancy_bloat_uses_tarball_size_not_runtime.md`](../../2026.05/2026.05.13/infra_vibrancy_bloat_uses_tarball_size_not_runtime.md): a "shipping size" number being computed from bytes the build never consumes. That fix split tarball vs code-size; this one drops the section that never builds at all.

---

## Root cause

Two surfaces summed across every `VibrancyResult` without filtering on `r.package.section`:

- [`buildReportSummary`](../../../../extension/src/vibrancy/views/report-html.ts) (`extension/src/vibrancy/views/report-html.ts:425-507`) — `totalOwnBytes`, `totalUniqueBytes`, `totalAllBytes` reduced over the full `results` array.
- [`prepareChartData`](../../../../extension/src/vibrancy/views/chart-html.ts) (`extension/src/vibrancy/views/chart-html.ts:104-128`) — `withSize` mapped the full `results` array; `totalBytes` for percentage math used that full sum.

The existing "Include dev" toggle ([`report-script.ts:160`](../../../../extension/src/vibrancy/views/report-script.ts)) only hid dev rows in the **package table** at the bottom; it did not affect the server-rendered Total Size card or the chart. So even with the toggle off, the two summary surfaces still counted dev deps.

---

## Fix

`dev_dependencies` are unconditionally excluded from both APK-shipped-size surfaces. The "Include dev" toggle keeps its existing meaning for the package table.

- **`buildReportSummary`** filters `results` through `r.package.section !== 'dev_dependencies'` before computing `totalOwnBytes` / `totalUniqueBytes` / `totalAllBytes`. The `data-total-size-*` attributes used by the client-side footprint toggle reflect the same exclusion.
- **`prepareChartData`** drops `section === 'dev_dependencies'` from the input before mapping to sized segments, so `totalBytes` (the percentage denominator) and the per-segment bars both reflect shipped bytes only.
- **Caption** under the Size Distribution heading: `"Excludes dev_dependencies — they never ship to the APK / IPA / web bundle."` So users see the exclusion immediately, without having to discover it via tooltip.
- **Total Size tooltip caveat** (`packageDashboard.summary.caveatLine1`) extended with an explicit "Excludes dev_dependencies (build_runner, lints, saropa_lints, etc.) — they never ship to the APK / IPA / web bundle." line, alongside the existing code-size and tree-shaking caveats.

Why not "respect the Include-dev toggle" instead of unconditionally excluding:
- The toggle's semantic is "show dev rows in the table" — useful when triaging stale dev tooling.
- The Total Size and Size Distribution cards' semantic is "shipped bytes" — there is no scenario where a dev dep contributes shipped bytes. Allowing the toggle to add dev bytes to "Total Size" would only ever produce a wrong answer.
- Keeping the two semantics independent matches what users intuit: the table is for inventory, the size card is for shipping cost.

---

## Files changed

- `extension/src/vibrancy/views/report-html.ts` — `buildReportSummary` filters `results` to `shippableResults` before summing all three size totals.
- `extension/src/vibrancy/views/chart-html.ts` — `prepareChartData` drops `section === 'dev_dependencies'` before sizing; `buildChartSection` renders the `<p class="chart-caption">` row.
- `extension/src/vibrancy/views/chart-styles.ts` — new `.chart-caption` style block.
- `extension/src/i18n/locales/en.json` — extended `packageDashboard.summary.caveatLine1`; added `packageDashboard.sections.sizeDistributionCaption`.
- `extension/src/test/vibrancy/views/report-html.test.ts` — added 4 tests: Total Size summary exclusion, Size Distribution chart exclusion, caption presence, tooltip caveat copy.
- `CHANGELOG.md` — `### Fixed (Extension)` bullet under `[Unreleased]`.

24 other locale JSON files keep the old `caveatLine1` text and have no `sizeDistributionCaption` key. They fall back to English at runtime via the existing `l10n.ts` resolver; the MT pipeline handles re-translation separately per the established `i18n_nllb` workflow, which the user explicitly prohibits running ad-hoc.

---

## Test result

- Targeted (`npm test -- --grep "dev_dependencies"`): 4 passing — 2 new (size summary exclusion, caveat) + 2 pre-existing lint-rule tests that share the substring.
- Targeted (`npm test -- --grep "Distribution"`): 2 new tests passing (chart exclusion, caption).
- Targeted (`npm test -- --grep "report"`): 165 passing.
- Full suite: 1181 passing / 10 failing. The 10 failures are pre-existing in `cross-file commands` (confirmed by stash → 1177 passing / 10 failing on `main`).

---

## Out of scope (deliberately not touched in this commit)

- Two unrelated uncommitted edits in `extension/src/vibrancy/scan-helpers.ts` and `extension/src/vibrancy/services/report-exporter.ts` (a `scanTimestamp` field for a future "Scanned X ago" pill in the dashboard hero) — different feature, different author/session WIP. Left in the working tree untouched.
- The four bug-fix files from the prior task on this branch (`pass_existing_future_to_future_builder` rule + fixture + test + plan) — already staged before this session and unrelated to dashboard size metrics.
- Re-translation of `caveatLine1` and the new `sizeDistributionCaption` key into the 24 non-English locale bundles — handled by the project's MT pipeline (`i18n_nllb`), which is gated behind explicit user authorization per `~/.claude/CLAUDE.md`.


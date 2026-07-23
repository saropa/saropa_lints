# Opportunities column false positives and Package Detail section

A user report that the Package Dashboard's Opportunities column listed
`README.md` as an adoptable feature led to a fix in the changelog-mining
extraction logic, plus a new Opportunities section in the Package Detail
sidebar with per-feature code/documentation links.

---

## Summary

`extractApiNames` (`extension/src/vibrancy/services/changelog-opportunities.ts`)
mines changelog bullets for adoptable API names using three regex signals:
backtick spans, dotted PascalCase member access (`ReelText.rich`), and
multi-hump PascalCase type names. The dotted-access regex,
`\b[A-Z][A-Za-z0-9]*\.[A-Za-z_]\w*`, matches any `Word.word` span by shape
alone — `README.md` fits it exactly as well as a real API reference like
`ReelText.rich`, so a changelog bullet mentioning the file surfaced as an
"opportunity" with a badge count on the dashboard's Opportunities column.

## What changed

- Added a `NON_CODE_EXTENSIONS` set and `looksLikeFilename(name)` helper to
  `changelog-opportunities.ts`, applied as a final filter across all three
  extraction signals. The set covers document extensions (md, txt, json,
  yaml, yml, html, css, xml, csv, pdf, toml, ini, rst, adoc, docx, zip, and
  common image formats) and source-file extensions (dart, js, ts, jsx, tsx,
  py, rb, java, kt, swift, go, rs, c, cpp, h, sh, gradle, podspec, plist) —
  the latter added because the user's ask covered "anything that is NOT a
  method name," not just documents.
- A delegated code review (general-purpose subagent) caught a real
  false-negative risk in the first draft: the initial extension set included
  `log`, `lock`, and `doc`, which collide with common Dart API member names
  (`Logger.log`, `Mutex.lock`, `Lock.lock`). Including them would have
  silently dropped genuine opportunities whenever a changelog bullet named
  one of those APIs. All three were removed from the set (with a comment
  explaining why), keeping `docx` (no such collision).
- Added a new Opportunities section to the Package Detail sidebar
  (`extension/src/vibrancy/views/package-detail-html.ts`,
  `buildOpportunitiesSection` / `buildOpportunityItem`), rendered after the
  Changelog section. Lists each changelog bullet that still names at least
  one symbol absent from project source (`r.unadoptedApiNames`), and for
  each such symbol renders a code chip plus a "View code" link (GitHub
  per-repo code search, omitted when no repo URL resolves) and a "View docs"
  link (pub.dev documentation search). New CSS in `package-detail-styles.ts`
  and l10n keys under `packageDetail.opportunities.*` in `en.json`.

### Files touched

- `extension/src/vibrancy/services/changelog-opportunities.ts` — filename
  exclusion filter on `extractApiNames`.
- `extension/src/test/vibrancy/services/changelog-opportunities.test.ts` —
  6 new tests: README.md/CHANGELOG.md/pubspec.yaml exclusion, a real API
  name surviving alongside a filename reference, `Logger.log`/`Mutex.lock`
  surviving the extension collision fix, and `MyWidget.dart` exclusion.
- `extension/src/vibrancy/views/package-detail-html.ts` — new Opportunities
  section builders, wired into `buildPackageDetailBody`.
- `extension/src/vibrancy/views/package-detail-styles.ts` — `.opp-item*`
  CSS rules.
- `extension/src/i18n/locales/en.json` — `packageDetail.opportunities.*`
  keys (`header`, `viewCode`, `viewDocs`).
- `extension/src/test/vibrancy/views/package-detail-html.test.ts` — 6 new
  tests covering: empty state, bullet/version/count rendering, code+docs
  link URLs, the no-repo-URL fallback, a fully-adopted bullet dropping out,
  and HTML-escaping of untrusted bullet text and API names.
- `CHANGELOG.md` — new `[Unreleased]` entries under `### Added` and
  `### Fixed`.

### Verification

`tsc -p tsconfig.test.json` compiled clean after each round of edits.
`mocha` was run scoped to exactly the three touched test files
(`changelog-opportunities.test.js`, `package-detail-html.test.js`,
`opportunities-html.test.js`) rather than the ~3000-test full suite; all 46
tests passed on the final run.

A delegated code review (general-purpose subagent) checked correctness,
XSS/escaping, architecture/reuse, test coverage, and i18n across the diff.
Findings and disposition:

- **Fixed**: the `log`/`lock`/`doc` extension-collision false-negative
  described above (confirmed real, not hypothetical).
- **Fixed**: zero test coverage existed for the new
  `buildOpportunitiesSection`/`buildOpportunityItem` functions — only the
  extraction-layer tests had been added. Six tests were added covering the
  gap, including the case (`Logger.log`) that motivated the collision fix.
- **Noted, not acted on**: `buildOpportunitiesSection` reimplements the
  bullet-to-unused-API cross-referencing that `opportunities-html.ts`'s
  `buildFeatures` already does for the separate multi-package dashboard. The
  two consumers render different output shapes (a per-package sidebar
  section with code/docs search links vs. a dashboard card with chips and
  project file locations), so this was left as accepted duplication rather
  than forced into a shared helper for two call sites — matches this
  project's convention of tolerating per-file duplication over premature
  abstraction until a third consumer appears.
- **Confirmed clean**: no XSS gaps — `bullet.text`, `bullet.version`, and
  API names (untrusted external changelog content) are escaped via
  `escapeHtml`, and search-query URLs use `encodeURIComponent`. No i18n
  key collisions or hardcoded strings in the new builders.

The extension's machine-translation regeneration
(`extension/scripts/i18n/generate_locales.py`) was NOT run — it imports the
project's NLLB engine and is gated by a standing hard-stop on running any
translation pipeline without an explicit, in-the-moment authorization naming
that specific run. All 24 non-English locale files are confirmed missing
the new `packageDetail.opportunities.*` keys; the l10n runtime falls back to
English for a missing key, so the new sidebar section renders (in English)
for non-English users until that pipeline is run on its own cadence.

## Outcome

Shipped. Both fixes were swept into an already-in-flight commit
(`5d3fbe4a`, an unrelated `device_calendar_plus` rule pack task) by this
repository's convention of committing the working tree wholesale rather than
scoping commits to one workstream; this file documents the Opportunities
work specifically, separate from that commit's own finish report
(`device_calendar_plus_rule_pack.md`, same directory).

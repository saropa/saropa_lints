# Package Vibrancy: remove one-click "Update All" suggestion, add inline consolidated changelog

The Package Vibrancy background watcher polled pub.dev on a timer and, on finding newer
dependency versions, raised an unsolicited toast offering a one-click **Update All** action that
ran the bulk upgrade planner. Bulk-pulling every newest version from a passive notification —
without reviewing any individual changelog — is a supply-chain attack vector: a freshly-published
malicious release is adopted across the entire dependency graph in a single tap. Separately, the
package detail screen already had each release's changelog scraped during the scan but discarded
it, surfacing only an external "View Changelog" link, so a per-package upgrade was still a blind
decision.

The fix removes the bulk-upgrade *suggestion* (not awareness of updates, and not the deliberate
command-palette bulk commands) and renders the already-scraped changelog inline so a per-package
upgrade is a reviewed decision.

## Finish Report (2026-06-14)

### Scope
(B) VS Code extension (`extension/`, TypeScript). No Dart lint rules, `tiers.dart`, or
`analysis_options*.yaml` touched.

### Deep review
- **Logic & safety.** The new-version toast handler's `switch` now has only `View Details` and
  `Dismiss` arms; the removed `Update All` arm was the sole caller of `planUpgrades` from this
  surface. `createNotificationActions()` no longer emits `Update All`, so the label can never be
  returned and matched. No other code path invoked the bulk planner from the toast.
- **Architecture & adherence.** The inline changelog reuses the existing XSS-safe
  `markdownToHtml` renderer (escapes HTML, allow-lists link schemes) rather than introducing a
  second markdown converter. External, untrusted changelog bodies (GitHub `CHANGELOG.md` first,
  pub.dev fallback) are escaped before rendering. The new section follows the established
  `section()`/builder pattern in the package detail view and is inserted between the version and
  community sections.
- **Performance.** No new fetching: the changelog (`updateInfo.changelog.entries`) is already
  produced during the scan and capped at 20 entries with a `truncated` flag; the new code only
  renders existing data.
- **Documentation.** Both source edits carry block comments stating the supply-chain rationale
  for removing the bulk action and the trust boundary for rendering external changelog bodies.

### Testing validation
- **Existing-test audit.** `freshness-watcher.test.ts` pinned the old three-action list
  (`View Details`/`Update All`/`Dismiss`); its assertion was rewritten to pin the new
  awareness-only list plus an explicit guard that `Update All` must be absent. The
  package-detail HTML tests were audited; none pinned the discarded external-only changelog
  behavior, so the existing assertions stand and new ones were added.
- **New tests.** Four changelog-section tests in `package-detail-html.test.ts`: inline rendering
  of dated and undated entries, an HTML-injection guard (raw `<img onerror>` must be escaped, not
  rendered), the truncation note linking to the full pub.dev changelog, and absence of the
  section when there is no update. One new freshness-watcher test asserts the toast must not offer
  a one-click bulk `Update All`.
- **Test wiring.** `freshness-watcher.test.ts` and `package-detail-html.test.ts` existed but were
  never compiled or executed (absent from `tsconfig.test.json` include and the `npm test` glob).
  Both were wired into both. Wiring `freshness-watcher.test.ts` into the type-check surfaced a
  dormant `TS2740` — its local `makeResult` helper was missing 12 `VibrancyResult` fields; the
  helper was completed so the file type-checks (CI runs `tsc && mocha`, so a type error would
  block the suite).
- **Results.** `tsc -p tsconfig.test.json` exits 0; the two target files run 27 passing.
  Full-project `tsc --noEmit` exits 0.

### Extension l10n
- New user-facing strings route through `l10n()` with keys added to
  `extension/src/i18n/locales/en.json`: `packageDetail.section.changelog` and
  `packageDetail.changelog.{intro,versionDated,truncated,viewFull}`. Interpolation uses `{token}`
  placeholders, no English concatenation. No dev/debug strings were added to the catalog.
- The toast labels `View Details` / `Dismiss` remain hardcoded literals; they pre-date this change
  (the handler matches them by exact literal) and were left untouched.
- `en.json` changed, so translated catalogs are stale. Regeneration runs the machine-translation
  pipeline and was deliberately NOT executed here; it must be run separately:
  `D:\Tools\Python\Python314\python.exe D:\src\saropa_lints\extension\scripts\generate_translations.py`.
  The publish coverage gate (`generate_locales.py --fail-on-missing`) will block a release until
  the catalogs are regenerated.

### Project maintenance
- CHANGELOG updated under `[Unreleased]`: one Added (Extension) bullet for the inline consolidated
  changelog, one Changed (Extension) bullet for the removed bulk action and its security rationale.
- README verified — no rule/doc counts changed.
- Roadmap — N/A, no lint rules added or modified.
- A misconfigured repo hook was corrected as part of finishing the work: the `PostToolUse`
  spelling-guard in `.claude/settings.json` used a cwd-relative script path that resolved against
  the wrong directory and failed on every edit; it now uses `$CLAUDE_PROJECT_DIR` so it resolves
  from the project root regardless of cwd.
- No bug archive — task did not close a `bugs/*.md` file.

### Files changed
- `extension/src/vibrancy/extension-activation.ts` — removed the `Update All` arm from the
  new-version toast handler; added rationale comment.
- `extension/src/vibrancy/services/freshness-watcher.ts` — `createNotificationActions()` now
  returns awareness-only actions; added rationale doc comment.
- `extension/src/vibrancy/views/package-detail-html.ts` — new `buildChangelogSection()`, wired
  into the detail body; import of `markdownToHtml`.
- `extension/src/vibrancy/views/package-detail-styles.ts` — styles for the changelog section.
- `extension/src/i18n/locales/en.json` — new changelog section/keys.
- `extension/src/test/vibrancy/services/freshness-watcher.test.ts` — rewritten action assertion +
  no-`Update All` guard; completed `makeResult` helper.
- `extension/src/test/vibrancy/views/package-detail-html.test.ts` — four changelog-section tests.
- `extension/tsconfig.test.json` — include the two previously-unwired test files.
- `extension/package.json` — add the two test files to the `npm test` glob.
- `CHANGELOG.md` — Added/Changed (Extension) bullets.
- `.claude/settings.json` — fix the spelling-guard hook path.

### Outstanding
- Translated locale catalogs must be regenerated (command above) before release.

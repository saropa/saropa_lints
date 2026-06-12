# Extension UI-language coverage gating

**Problem:** Four locales sat far below 100%
(`uk` 23%, `ur` 10%, `vi` 4%, `zh` 4%) yet were offered to users
identically to the 20 complete ones, with no signal that they were
incomplete. The language picker needed to reflect which locales are
fully translated.

Chosen approach: **offer every locale but badge the
incomplete ones with their measured coverage percent** — keep them selectable,
make the gap honest in the picker rather than hiding or dropping locales.

## Finish Report (2026-06-11)

### 2. Scope
**(B) VS Code extension** — TypeScript picker, the Python i18n generator, the
runtime English catalog, a new generated JSON, and a test. No Dart lint-rule or
analyzer-plugin code touched. CHANGELOG updated.

### 3. Deep review
- **Logic & safety:** The picker reads `coveragePct` with optional chaining and
  treats a missing entry as complete (no badge), so a locale absent from the
  coverage file degrades to "clean" rather than throwing. The Python
  `write_coverage_json` merges into any existing file, so a partial
  `--locales bn,de` run updates only its own entries and never clobbers the
  others. Corrupt/partial prior JSON is caught and rebuilt rather than aborting a
  translation run.
- **Architecture:** Single source of truth — coverage is computed once from the
  same `LocaleStats` the audit/translate already produce, written to one JSON the
  picker imports. The badge can never claim more coverage than was measured.
- **No new duplication introduced.** Pre-existing duplication of the locale set
  across four sites (`--locales` default, `runtime.ts` catalogs,
  `languagePick.ts` endonym tables, `package.json` enum) was left as-is; flagged
  to the user, not in scope for this change.
- **Performance:** Picker reads an in-memory imported JSON (no I/O at pick time).
  Audit/translate write one extra small JSON per run.

### 4. Testing validation
**A. Existing-test audit.** Grepped the extension test tree for every touched
symbol (`languagePick`, `buildUiLanguageQuickPickItems`,
`formatLanguageChoiceLabel`, `locale_coverage`, `coverageBadge`,
`uiLanguage.pick`). One match: `extension/src/test/views/languagePick.test.ts`.
It pinned ordering + length (26 items); the change preserves both, so its existing
assertions still hold. **The test was orphaned** — it was not in
`tsconfig.test.json`'s allow-list `include`, so it had never compiled or run.
Wired it (plus its `src/i18n/runtime.ts` and `src/i18n/languagePick.ts` deps)
into the test tsconfig so it now runs in the suite.

**B. New behavior.** Extended `languagePick.test.ts` with a case asserting: `zh`
carries a badge stating 4%, a complete locale (`de`) and English carry no badge,
and `auto` keeps its `→` resolved-language hint (not a badge).

Commands run:
- `npx tsc --noEmit -p tsconfig.json` → exit 0 (production type-check clean).
- `npx tsc -p tsconfig.test.json` → exit 0.
- `mocha out-test/test/views/languagePick.test.js` → 2 passing.
- `mocha "out-test/test/views/**/*.test.js"` → 179 passing (no regression).

### 5. Extension l10n validation
- **String audit:** One new user-facing string added — the coverage badge —
  routed through `l10n('uiLanguage.pick.coverage', { pct })` with the key added to
  `extension/src/i18n/locales/en.json` and `{pct}` token interpolation (no
  concatenation). No dev/debug strings leaked into the catalog.
- **Catalog regeneration (5B) — NOT RUN.** Regenerating the 24 translated
  catalogs runs the NLLB machine-translation pipeline, which is under a hard
  standing prohibition (never run NLLB without an explicit in-the-moment command
  naming that run). The new key therefore exists only in `en.json`.
- **Coverage gate (5C):** The new key is **missing in all 24 translated locales**
  until regenerated. At runtime the badge falls back to English in those locales
  (acceptable degradation). `generate_locales.py --fail-on-missing` will report 24
  missing and block publish until the operator regenerates. See "Not yet
  verified" below.

### 6. Project maintenance & tracking
- CHANGELOG: added `### Changed (Extension)` entry under `[Unreleased]`.
- README verified — no rule-count or product-fact change.
- ROADMAP: SKIPPED — no lint rule added or changed.
- `pubspec`/`package.json` deps: unchanged.
- Guides reviewed — `plans/guides/EXTENSION_LOCALIZATION_GUIDE.md` still accurate;
  no edit required for this change.
- No bug archive — task did not close a `bugs/*.md` file.

### 7. Persistence
Finish report saved: plans/history/2026.06/2026.06.11/extension_language_coverage_gating.md

### 8/9. Files & commit
Files changed:
- `extension/src/i18n/locale_coverage.json` (new — generated coverage source,
  seeded from the current audit numbers)
- `extension/scripts/i18n/generate_locales.py` (`write_coverage_json` + calls
  from the audit and translate paths)
- `extension/src/i18n/locales/en.json` (`uiLanguage.pick.coverage` key)
- `extension/src/i18n/languagePick.ts` (`coverageBadge` + badge wiring)
- `extension/src/test/views/languagePick.test.ts` (new badge test)
- `extension/tsconfig.test.json` (wire the orphaned test + i18n deps into the suite)
- `CHANGELOG.md` (Changed (Extension) entry)

### Outstanding
- Translated catalogs need regeneration to localize the new badge string (NLLB —
  user-initiated only).
- The four-way locale-list duplication remains; collapsing it into the manifest
  is a separate, larger refactor the user has not authorized.

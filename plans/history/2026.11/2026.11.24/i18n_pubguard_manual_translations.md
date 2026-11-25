# i18n: Vibrancy pub-guard manual translations

Finish report, 2026-11-24.

## Objective

The Vibrancy pub-guard commit 30bda0046 added about 41 `en.json` and `package.nls` strings that shipped English-only in 24 locales. Several catalogs also carried a stale `pubGuard.skipped` key containing leaked machine-translation prompt text.

## What changed

- Hand translations for all pub-guard strings in the 24 locales (ar bn de es fa fil fr he hi id it ja ko nl pl pt ru sw th tr uk ur vi zh), written into `extension/scripts/i18n/dictionaries.py`, `extension/src/i18n/locales/<lang>.json`, and `extension/package.nls.<lang>.json` (commit 84aa2cc42). No machine translation was run.
- Keys whose English text was reworded were re-translated.
- The garbled `ur` value for `code_style_preferences` was replaced.
- The stale `pubGuard.skipped` key was removed from the catalogs.
- Follow-up (this change):
  - Added `pubGuard.explain.unknown` (fallback value label in the Explain Last Vibrancy Skip modal) to all 24 locale JSONs at the `en.json` position, preserving each file's line endings and indent. `fil` already had the dictionary entry "hindi alam"; the other 23 received a dictionary entry.
  - Removed three stale-source dictionary entries: `fr` and `vi` "Package Vibrancy skipped a pub query so pubspec.lock is not rewritten. {reason}", and `hi` "The Dart SDK version on PATH could not be determined and the project has no recorded SDK version."
  - Removed identical duplicate keys: `hi` "{count} downloads in the last 30 days" and `fil` "{total} transitive deps ({shared} shared)".
  - Added dictionary entries for `pubGuard.sdkMismatch` and `pubGuard.lockSdkConstraint` in every locale, keyed by the current English text with the value copied from each locale JSON, so a regeneration keeps the hand text. Placeholders verified identical.
- CHANGELOG `### Internal` bullet added under 17.9.0.

## Validation

- `dictionaries.py` parses with `ast`.
- `D:\tmp\check_pubguard_i18n.py`: key parity PASS, placeholders PASS, untranslated non-Latin PASS, dictionaries.py PASS, JSON-without-dictionary-entry PASS. Informational only: end-of-line diffs (git blob vs working tree under autocrlf; each file's working-tree line endings unchanged), `PATH` and `.dart_tool/version` kept identical by design, and "Dart SDK" rendered as the localized "SDK Dart" / "Dart-SDK" in de, es, fr, it.
- `generate_locales.py --mode audit --fail-on-missing`: 0 missing in 24 locales (59520 entries, 100%).

## Open items

- No native-speaker review. ar, fa, ur are the least certain.
- Pre-existing leaked machine-translation prompt text (addressed in the hardening section below):
  - `id.json` (11 keys): welcome.hero.subtitle, welcome.card.engine.body, welcome.card.monitoring.why, stylistic.desc.widget_style, packs.domainDesc.storage-persistence, packs.domainDesc.navigation-deep-links, triageDash.hintSameAsTree, projectMap.reports.intro, debug.engine.description.lspServer, debug.engine.recommended.analyzerPlugin, notify.lane.updated.
  - `package.nls.id.json` (2 keys): config.property.docPlacement.openSignals.description, walkthrough.step.walkthrough.aboutSaropa.description.
- `he.json` rulesTiers.configFile.maxIssues.desc contains a garbage character loop (addressed below).
- `ur.json` opportunities.report.noContent contains a run of "1" characters (addressed below).

## Hardening and catalog gate (2026-11-24)

The locale audit never opened the shipped catalogs: `_run_audit` built each locale from `TRANSLATIONS` plus the MT cache, so a key absent from a catalog (e.g. `pubGuard.explain.unknown`) and corrupted catalog values were invisible to the `--fail-on-missing` publish gate.

Changes:
- `extension/scripts/i18n/locale_catalog_check.py`: absent keys (by key, lists expanded by index), extra keys (warning), dictionary entries whose English source no longer exists (stale; `--fail-on-stale`, off by default), catalog values with no dictionary entry (warning).
- `extension/scripts/i18n/check_locale_garbage.py` (standalone and inside the audit): leaked MT prompt headers (line-start markers, single constant), 1-3 character repeat loops (benign rulers/punctuation exempt), and wrong-script text (CJK/kana/hangul incl. Ext-A, fullwidth and Jamo outside ja/zh/ko; Han runs in ko; Cyrillic outside ru/uk; Hebrew in ar/fa/ur; Arabic script in he; Latin sentences in ja/zh/ko), with a per-key exemption for characters present in the English source.
- `generate_locales.py`: `_catalog_gate` reports separate counters for dictionary gaps, absent keys, garbage and stale entries with a distinct remedy each; the same gate order runs in audit and normal mode; absent and garbage findings are folded into `locale_coverage.json` / README coverage before they are written.
- Tests: `extension/scripts/i18n/tests/test_locale_catalog_check.py` (helpers, gate exit codes in a hermetic temp extension dir, coverage folding, false-positive fixtures).

Catalog repairs (hand translation of the current English, dictionary entries added so regeneration keeps them): the 15 known items above (id prompt leaks, he loop, ur run), 4 further prompt leaks (es, pt), 166 wrong-script values in the first pass and about 140 cross-script values (Arabic/Cyrillic in he, Cyrillic in ar/fa/ur/ja/ko and others, Han in ko) in the second; terminology in the pubGuard block aligned per locale.

Validation: `check_locale_garbage.py` 0 findings; `generate_locales.py --mode audit --fail-on-missing --fail-on-drift --check-cognates` exit 0 (0 gaps, 0 absent keys, 0 garbage); i18n tests 213 passed, 5 failed — the 5 (`test_phrase_split` TestFallbackLog x3, `test_progress` prefetch callback, `test_qwen_process_hygiene` POSIX kill) fail identically on the prior HEAD.

Open: no native-speaker review of any repaired value; the 47k "low-quality" audit entries and ~2.5k catalog values without dictionary backing are unchanged.

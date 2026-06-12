# i18n brand/identifier shield repair + NLLB phrase splitter & fallback report

`extension/package.nls.ar.json` rendered the brand as `"Saropa الوبر"` ("Lints"
machine-translated to Arabic). The translation pipeline shielded only the bare
word `"Saropa"`, so the *rest* of every brand/proper-noun/code-identifier was
being machine-translated or transliterated across the locale catalogs. This
change (a) repairs the shipped catalogs, (b) gates the terms so future
regenerations stay correct, and (c) fixes the NLLB pipeline so long strings are
translated phrase-by-phrase instead of silently dropping to Google/English, with
proper reporting.

## Finish Report (2026-06-10)

### 2. Scope
- **(C)** build tooling — Python i18n scripts under `extension/scripts/i18n/`.
- **(B)** extension localization — generated locale catalogs (`extension/package.nls.<lang>.json`, `extension/src/i18n/locales/<lang>.json`) and manifest brand strings.
- **NOT (A)** — no Dart lint rules, analyzer plugin, tiers, or `LintImpact` touched. `extension/src/i18n/locales/en.json` (the English source) was NOT modified; only the translated catalogs and the shield/engine tooling.

### 3. Deep review
- **Shield ordering (`mt_fallback.py` `_DO_NOT_TRANSLATE`)**: terms are longest/most-specific first so `"Saropa"` cannot mask inside `"Saropa Lints"`. The existing word-boundary `_BRAND_PATTERNS` (`(?<![A-Za-z])term(?![A-Za-z])`) handles the multi-word and dotted/underscored identifiers via `re.escape`. Verified by `test_multiword_product_name_shielded_as_unit` / `test_tool_brand_names_shielded`.
- **Phrase splitter (`nllb_engine.py`)**: clause patterns require trailing whitespace, so URLs (`https://…`) and dotted versions (`1.2.3`) are never split mid-token (pinned by `test_url_is_never_split_midtoken`). Split is lossless — separators are captured by `re.split` and rejoined byte-identically (an empty translation reproduces the source). Recursion terminates: an unsplittable atom returns `[text]` → `None` → reported.
- **Fallback recording (`mt_fallback.py`)**: records a Google result only when NLLB was the primary engine that bounced it, and an English echo always — so a Google-primary run (NLLB absent) doesn't spam the report with expected Google output.
- **No logic duplication**: `_translate_via_phrases` mirrors the existing `_translate_via_sentences` contract (per-piece routing, partial-failure keeps English, echo guard) rather than inventing a new shape.

### 4. Testing
- **Audited existing tests** referencing the changed symbols: `tests/test_mt_fallback.py` (shield/`_cache_value_is_clean`), `tests/test_nllb_wiring.py` (engine selection/`_translate_one`), `tests/test_mt_provenance_modes.py`. The `_DO_NOT_TRANSLATE` growth and the new fallback recording did not break any existing assertion (the shield tests assert round-trip, not the exact tuple contents).
- **Added** `tests/test_phrase_split.py` (11 cases): lossless split, URL-never-split, newline-preferred, no-delimiter-single, clause translate+rejoin, partial-clause-failure keeps English, and fallback recording for english/google/nllb-success. Also added two shield tests to `test_mt_fallback.py`.
- **Ran**: `python -m unittest test_phrase_split test_mt_fallback test_nllb_wiring test_mt_provenance_modes` → **57 passed**. Compile + import checks clean; fallback-report writer smoke-tested.

### 5. Extension l10n
- The translated catalogs were **hand-repaired** (not regenerated) — a deliberate exception to "do not hand-edit generated catalogs", because the repair cannot run through MT (NLLB is hard-banned) and the shield gate makes a future regen reproduce the same correct values. `en.json` unchanged → key parity intact, coverage unaffected (no keys added/removed).
- ~314 of ~361 mangled occurrences repaired and verified to **0 residual** for the 5 core brands (count-based detector). Repair tactics: brand token/form maps (334), backtick code-span force (54), filename suffix-anchor (186), transliteration maps (40), `dev_dependencies` regex+forms (34). All 49 catalogs parse; no double-token artifacts; spot-checked `pub.dev`/Turkish-suffix/`violations.json` preserved.
- **Gated** (future-correct) in `_DO_NOT_TRANSLATE`: `Saropa Lints, VS Code, pub.dev, GitHub, OWASP, SPDX, OSV, Dart, Flutter` + identifiers `saropa_lints, analysis_options, pubspec.yaml, pubspec.lock, violations.json, workspace.textDocuments, dev_dependencies, build_runner, dart analyze, dart format` + `Saropa`.

### 6. Maintenance
- CHANGELOG: `### Fixed (Extension)` brand/identifier bullet under 13.12.4 + overview clause; Maintenance bullet for the phrase-splitter/fallback-report. (Both already in HEAD via a concurrent-session commit; see Section 9.)
- README verified — no rule/doc counts changed.
- Roadmap — no lint entries affected.
- `No bug archive` — task did not close a `bugs/*.md` file (user-reported symptom, no bug file existed).

### 7. Residual (honest)
~85 occurrences NOT auto-repaired — gated, so a future regen fixes them, but they cannot be safely forced in place (NLLB regen is hard-banned):
- `dart analyze`/`dart format` (~70): semantically translated ("dart" → projectile "dardos/arrows/phi tiêu"), reordered; mostly reads as acceptable localized "Dart analysis".
- ~15 dropped/garbled sentences: ar `extension.description` dropped "Dart"; fa/th `violations.json` became a verb phrase.

### 8. Pipeline changes (core logic)
- `nllb_engine.py`: new `_split_into_phrases` / `_translate_via_phrases`; token-gate path now tries sentence-split → phrase-split → `_record_long_input` (records EVERY over-gate unsplittable input, replacing the once-only `_long_input_skip_logged` flag). New `long_inputs()` / `reset_long_inputs()`.
- `mt_fallback.py`: `_DO_NOT_TRANSLATE` expanded to 20 terms; new `_fallback_log` + `_record_fallback` / `fallback_log()` (cleared in `reset_engine_stats`); `_translate_one` records google/english fallbacks.
- `generate_locales.py`: imports `fallback_log`; calls `reset_long_inputs()` at run start; new `write_fallback_report()` → `reports/i18n_nllb_fallbacks.md`, printed in the run summary.

### 9. Concurrency note
The working tree was modified and committed by a **concurrent session** (new commits `affddbec`/`29d62604`/`f2a4e560` — one with a bare `@` subject — appeared, and `git status` shifted between calls). All of this task's code changes were verified present in `HEAD` (ar `displayName` = "Saropa Lints", 20 gate terms, CHANGELOG brand bullet, `test_phrase_split.py` tracked) — i.e. already committed under those concurrent commits' (unrelated) subjects. This report is committed separately so the i18n work has a properly-described durable record.

Out of standing scope but flagged earlier: `Dart`/`Flutter` and code-identifier transliteration were repaired here; the global CLAUDE.md gained a full-absolute-path rule for user-run script commands (outside this repo).

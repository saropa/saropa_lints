# Publish runs locale AUDIT only — never translates; add audit/abort menu options

This change adds two operator paths to the extension i18n build tooling (Python):
1. An abort option and a file-only audit of missing translations (gaps) and low-quality translations in the interactive `generate_locales.py` mode menu.
2. Audit-only locale coverage in the publish pipeline (no translation), prompting the operator to retry (default), ignore, or abort.

The standing hard rule is that publish must never kick off a machine-translation job; this change makes that explicit in the pipeline and gives the operator a read-only audit path plus a clean abort.

## Finish Report (2026-06-10)

### Scope
**(C) docs/scripts only.** All changes are Python build/i18n tooling under `extension/scripts/i18n/` and `scripts/`, plus `CHANGELOG.md`. No Dart lint rules, analyzer plugin, `example/`, `tiers.dart`, or extension TypeScript UI touched.

### What changed

**`extension/scripts/i18n/generate_locales.py`**
- `_choose_mode` menu adds `[4] Audit only` and `[a] Abort`; prompt is `[1/2/3/4/a]`, input lower-cased. EOF/Ctrl-C at the prompt now returns `abort` (previously silently defaulted to a gaps run).
- `--mode` argument gains the `audit` choice.
- New `_run_audit()`: builds each locale's mapping from the curated dictionary + existing MT cache ONLY (never `machine_translate`) — zero network calls — computes gaps via `compute_stats`, collects low-quality entries via `low_quality_entries`, writes the report, and honors `--fail-on-missing` (returns 1 when gaps remain, else 0).
- `main()` reordered: cache + unique-string collection moved ahead of the translation-run banners; `abort` returns 0 before any engine touch; `audit` returns `_run_audit(...)` before the MT engine is announced.
- `write_audit_report` gains an optional `low_quality_by_locale` param; `_append_low_quality_section` emits a "Low-quality translations (upgrade candidates)" section placed before the missing-strings early-return so it shows even on a gap-free locale.

**`extension/scripts/i18n/mt_fallback.py`**
- New `low_quality_entries()`: audit counterpart to `prune_low_quality` — returns (without removing) the source strings whose cached translation ranks below NLLB. Mirrors `prune_low_quality`'s selection exactly so the audit count equals what an upgrade run would redo; empty unless NLLB is the locale's primary engine.

**`scripts/modules/_extension_publish.py`**
- Renamed `regenerate_extension_locales_from_english` → `audit_extension_locales` (only 2 internal call sites). Drops the `SAROPA_I18N_MACHINE_TRANSLATE=1` env and runs `generate_locales.py --mode audit --fail-on-missing`. Return contract unchanged: True=clean / False=gaps / None=no i18n.
- `_prompt_locale_coverage_failure`: Retry is now listed first as the default, prompt `[R/i/a]`, wording states publish does not translate.
- `package_extension` gate loop + comments updated: Retry re-audits, Ignore ships with gaps, Abort stops.

**`scripts/publish.py`** — docstring: publish only audits locale coverage; closing gaps is an explicit separate step.

**`CHANGELOG.md`** — two Maintenance bullets under `[Unreleased]` (audit/abort menu options; publish no longer translates, audits + prompts).

### Deep review notes
- **Logic & safety:** audit path makes no network calls (verified — it never calls `machine_translate`/`prefetch`); abort returns before any engine init. `--fail-on-missing` semantics preserved end-to-end (audit exit 1 on gaps → `audit_extension_locales` returns False → operator prompt).
- **No duplication:** `low_quality_entries` mirrors `prune_low_quality` selection deliberately (consistency contract), reusing `_cache_key`/`_provenance`/`_LOW_QUALITY_PROVENANCE`. `_run_audit` reuses `compute_stats`, `print_summary`, `print_missing_samples`, `write_audit_report`.
- **Standalone safety preserved:** menu `[4]` / `--mode audit` without `--fail-on-missing` still exits 0, so the new read-only preview never gates a dev run.

### Tests
- Audited `tests/` for changed symbols. `prune_low_quality` referenced in `test_mt_provenance_modes.py` (left unchanged). No test referenced the renamed `_extension_publish` function except the module itself.
- Added `test_low_quality_entries_lists_without_removing` and `test_low_quality_entries_empty_when_google_primary` to `test_mt_provenance_modes.py`.
- Ran (Python `unittest`):
  - `test_mt_provenance_modes.py` — 10 passed (was 8).
  - `test_mt_fallback.py` — 18 passed.
  - `test_nllb_engine.py` — 10 passed.
  - `test_nllb_wiring.py` — 18 passed.
- Manual CLI verification: `generate_locales.py --mode audit --fail-on-missing --locales de` → exit 1 (1093 gaps), report written with low-quality section; `--mode audit --locales de` (no flag) → exit 0. All changed `.py` byte-compile.

### Maintenance
- CHANGELOG updated (Maintenance expander — build tooling, no user impact).
- README verified — no rule/doc count change, no update needed.
- ROADMAP — no lint rule change, untouched.
- pubspec — no dependency/release change, untouched.
- guides reviewed.
- No bug archive — task did not close a `bugs/*.md` file.

### Outstanding
None. The change is complete and self-contained in the i18n/publish tooling.

# Porting the i18n / Qwen translation pipeline to another project

Status: written from a read of this repo's code. The pipeline has NOT been ported to a
second project, so every "reusable as-is" claim below is unverified until a port is run.

## What the pipeline does

English JSON catalogs -> per-locale JSON catalogs, translated by a local Qwen model
(Ollama), with placeholder/brand shielding, a persistent cache, defect detection, and
CI gates. No paid or rate-capped API is used (Google is a fallback only; NLLB measured
~59% wrong vs Qwen ~21% and is deprecated).

## Files to copy

Source root: `d:\src\saropa_lints\extension\scripts\`

| Copy | Role | Project-specific? |
|------|------|-------------------|
| `i18n\mt_fallback.py` | Cache, provenance, shield/unshield of `{tokens}` and brand terms, write-time residue rejection | `_DO_NOT_TRANSLATE` (line ~54) and `_BRAND_PATTERNS` (~399): brand list |
| `i18n\qwen_engine.py` | Ollama client, prompt, model ladder (`qwen3:14b/8b/4b`), term glossary | `_TERM_GLOSSARY` (~1068): domain senses for this project's vocabulary |
| `i18n\generate_locales.py` | Gap-fill driver; calls the auto-prune hook | Output-path logic; messages mention `extension/scripts/i18n/...` |
| `i18n\bad_translations.py` + `bad_translations_blocklist.json` | Mechanical defect detector, `--check`, `--purge`, cache auto-prune | Blocklist entries are domain-specific; start empty |
| `i18n\verify_locales.py` | Shared helpers (`flatten`, `placeholder_problems`, `suspicious`, `discover`) | `discover()` hardcodes `src/i18n/locales/*.json` and `package.nls*.json` |
| `i18n\json_io.py`, `i18n\translator.py`, `i18n\tree_translate.py`, `i18n\term_color.py`, `i18n\dictionaries.py` | Support modules imported by `generate_locales.py`; `dictionaries.py` holds curated per-locale translations plus `COGNATES` and `DO_NOT_TRANSLATE` | `dictionaries.py` content is this project's; its `DO_NOT_TRANSLATE` is a second brand list besides `mt_fallback._DO_NOT_TRANSLATE` |
| `i18n\english_allowed.json` | Strings legitimately identical to English | Project content |
| `i18n\semantic_check.py` (optional) | Embedding-similarity review queue (`bge-m3` via Ollama). Report only; never run against a live server | None |
| `i18n\vram_report.py` | Prints used/free VRAM and the apps holding it, with per-app tips to disable hardware acceleration (VS Code, Firefox, Chrome, Edge, Discord, Slack, Teams). Report only; called once per run from `generate_locales.py`. Per-app data via PowerShell `Get-Counter` (Windows); silent without `nvidia-smi` | `_TIPS` app list |
| `i18n\coverage_report.py` | Per-locale coverage table; rewrites the block between `<!-- i18n-coverage:start/end -->` in the root `README.md`. `generate_locales.write_coverage_json` calls it | README path and marker block; reads `locale_coverage.json` |
| `i18n\requirements.txt` | `deep-translator` (Google fallback only) | None |
| `i18n\tests\` | Unit tests for the above | Run by path, not as a package |
| `generate_translations.py` | One-command entry point | Check its paths |
| `check_l10n_keys.py` (+ `test_check_l10n_keys.py`) | Verifies every `l10n('key')` literal in TS resolves in `en.json`; `--check-params` checks `{param}` use | TS source layout; `// l10n:passthrough` marker convention |

Keep the files in one flat directory: they import each other as siblings
(`sys.path.insert` on their own folder) and `mt_fallback` imports `qwen_engine` lazily.

## Values to change in the new project

1. **Catalog layout** in `verify_locales.discover()`: the English source files and the
   per-locale file pattern. This is the main coupling to the VS Code extension layout.
2. **Brand / do-not-translate terms**: `mt_fallback._DO_NOT_TRANSLATE` and
   `_BRAND_PATTERNS`. A missed brand gets transliterated by the model.
3. **Term glossary**: `qwen_engine._TERM_GLOSSARY`. Rebuild from a measured sample of the
   new project's mistranslations (this repo's was built from a 40-string comparison).
4. **Blocklist**: `bad_translations_blocklist.json` entries
   `{locale, en_regex, bad_regex}`; add as wrong renderings are found.
5. **Wrong-script table** `_SCRIPT_RANGES` in `bad_translations.py` if new locales are added.
6. **Python path** in docs and commands. This repo uses `D:\Tools\Python\Python314\python.exe -X utf8`.
   `-X utf8` is required on Windows for Unicode output.

## Environment

- Python 3.10+ (code uses `X | None` annotations). Stdlib only except `deep-translator` (optional).
- Ollama running at `http://localhost:11434` with `qwen3:8b` for an 8 GB GPU
  (`qwen3:14b` needs ~9.3 GB, `qwen3:4b` ~2.6 GB). Long run: ~23 words/min on the 8B model.
- `SAROPA_QWEN_PARALLEL` (1-4, default 2): concurrent Qwen requests; also sets the daemon's
  `OLLAMA_NUM_PARALLEL` (`qwen_engine.parallel_requests()` is the single source). 1 = serial.
  On an 8 GB card with `qwen3:8b` each extra slot costs ~0.5 GB; 2 slots left ~0.8 GB free, so
  3-4 can spill to CPU/RAM and run slower. An already-running Ollama daemon keeps its own
  setting (the script restarts its own daemon each run).
- `SAROPA_SKIP_QWEN=1` disables Qwen. `SAROPA_I18N_MACHINE_TRANSLATE=1` enables MT in the generator.
- Reference Qwen implementation also lives in the saropa.com repo (`d:\src\saropa.com`).

## Run order (per project)

1. Add keys to the English catalog; run `check_l10n_keys.py --check-params` (exit 0).
2. **User runs** the translation step (MT is never started by an agent):
   `generate_translations.py`. The generator first auto-prunes defective cache entries
   (prints "cleared N defective translations"), then Qwen fills gaps.
3. `bad_translations.py --check` must exit 0. If it fails, residual defects are real, or the
   detector over-flags: add blocklist/exemptions, do not weaken the detector.
4. `verify_locales.py` for missing keys, placeholder mismatches, identical-to-English values.
5. Optional: `semantic_check.py --locales de,ja --limit 200` for meaning-drift review.
6. Wire into CI: `check_l10n_keys.py --check-params` and `bad_translations.py --check`
   (add the second only after step 3 passes once, or CI goes red immediately).

## Behavior the new project inherits (do not break)

- **Cache** `.cache/mt_strings.json` is gitignored and unrecoverable once deleted;
  `bad_translations.py --purge` copies it to `mt_strings.json.bak` first.
- **Cache key**: `mt_fallback._cache_key(locale, text, engine)`: bare `locale:hash` for
  google, `engine:locale:hash` otherwise. Changing it orphans every cached translation.
- **Provenance** (`.cache/mt_provenance.json`): `manual` entries and curated dictionary
  entries are never pruned or overwritten.
- **Shield**: `{tokens}` and brands become ASCII sentinels (`ZZ<n>ZZ`) before MT and are
  restored after; any leftover residue (bare `ZZ`, `q<n>q`, `_PH<n>_`, `ПХ<n>`) is rejected at
  write time and flagged post hoc. A source that legitimately contains such a token is excused.
- **Hard flags** (auto-prunable): empty, leak, placeholder drift, wrong-script (2+ words, none
  in locale script), blowup (output >4x prose length + 10), blocklist. **Soft** flags are report-only.
- **Cache-only mapping pass**: after `prefetch_machine_translations`, `generate_locales` builds
  `HybridTranslator(locale, cache, cache_only=True)`. Without it, every string the engines had
  just failed on was retried live (Qwen + Google, 28 s timeout + backoff each, no output) and
  the run looked hung for minutes. `_translate_one(..., cache_only=True)` never calls an engine.
- **Parallel prefetch** (`mt_fallback._prefetch_parallel`): Qwen only; Google stays serial for
  its pacing gap. Each task writes only its own cache key. Progress, checkpoints and stop
  handling run on the main thread. Checkpoints write from `dict(cache)` / `dict(_provenance)`
  snapshots: writing the live dicts raised "dictionary changed size during iteration".
  `_record_engine` / `_record_fallback` are lock-guarded (unlocked `+= 1` loses counts).
- **Failed strings are not cached** (so a rerun retries them) and keep their existing shipped
  translation instead of regressing to English. The cache is saved BEFORE the english-regression
  guard, so an aborted locale does not discard the run's work.
- **Ctrl-C**: first press finishes in-flight strings, saves, stops before the next locale; second
  press cancels queued work. Never use `--allow-english-fallback` (overwrites good translations).
- Locale files are generated: never hand-edit them; fix the cache, dictionary, or blocklist.

## Known gaps carried over

- Parallel speedup is unmeasured under control: a `de` run showed 270 wpm at 2 slots vs 81-91 wpm
  serial on `bn` (different locales). Tune `SAROPA_QWEN_PARALLEL` per GPU.
- Small retry batches see many English fallbacks (`ar` 9 of 13, `bn` 13 of 16) while large
  batches succeed; cause not yet found (short labels such as "Mobile", "Web").
- Windows per-process VRAM counter reports allocations, which can exceed physical VRAM
  (WDDM pages the excess to RAM), so `vram_report.py` figures are upper bounds.

- Detector false-positive rate on the full flag set is unmeasured (16 of 16 sampled hard
  flags in non-leak classes were true positives).
- NLLB-origin strings (~67k of ~90k cached) have subtle word-sense errors the mechanical
  detector cannot see; `semantic_check.py` is the unverified answer to that.
- Qwen may reproduce a defect after a refill; the detector flags it again on the next run.

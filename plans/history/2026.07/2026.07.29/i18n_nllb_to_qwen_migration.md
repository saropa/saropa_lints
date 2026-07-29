# i18n Engine Migration: NLLB to Qwen

The extension's machine-translation pipeline was hardcoded to NLLB (a SentencePiece model requiring ctranslate2 + numpy + ~7 GB download) as its primary engine. NLLB's `mkl_malloc` failures across all three device configurations (CUDA, CPU/INT8, CPU) made it unusable, and the canonical Saropa MT engine had already moved to Qwen 3 via local Ollama in the saropa.com project.

## Changes

### New file: `extension/scripts/i18n/qwen_engine.py`

Qwen translation engine ported from `saropa.com/scripts/modules/i18n/i18n_qwen.py`. Exposes the 3-function contract (`qwen_lang_code`, `qwen_model_available`, `qwen_translate`) matching the same shape as `nllb_engine.py`. Key internals: GPU VRAM-aware model ladder (qwen3:14b/8b/4b), self-provisioning via `_ensure_ready()` (auto-starts Ollama daemon, pulls model), circuit breaker with sliding window, stall detection with daemon restart, `_build_prompt()` with per-locale script constraints for non-Latin targets. Strips `<think>` blocks and `/no_think` directives from output.

### Modified: `extension/scripts/i18n/mt_fallback.py`

- Replaced `_nllb_active_for` / `_nllb_fetch` with `_qwen_active_for` / `_qwen_fetch`.
- `_primary_engine()` returns `"qwen"` instead of `"nllb"`.
- Removed all NLLB-specific masking code (`_nllb_mask`, `_nllb_unmask`, `_nllb_marks_intact`, `_NLLB_PH` regex). Qwen reuses the generic `_fetch_translation` / `shield_placeholders` path (ASCII `ZZnZZ` sentinels).
- Added `"nllb"` to `_LOW_QUALITY_PROVENANCE` so legacy NLLB entries are upgrade-eligible.
- Added legacy cache promotion in `_translate_one` and `_iter_pending_texts`: on cache miss for the `qwen:` keyspace, probes `nllb:` and bare (Google) keyspaces via `cache_lookup_any`, copies the value forward under the `qwen:` key. Prevents "gaps only" mode from re-translating all ~1446 strings after the engine swap.

### Modified: `extension/scripts/i18n/generate_locales.py`

Menu text, mode labels, engine labels, report filenames updated from NLLB to Qwen. `nllb_engine.reset_long_inputs()` replaced with `qwen_engine.reset_run_state()`.

### Modified: `extension/scripts/generate_translations.py`

Removed `_reexec_under_standard_interpreter_if_free_threaded()` (NLLB's numpy dependency required standard interpreter; Qwen uses only stdlib). Removed `SAROPA_SKIP_NLLB` env var handling. Updated docstring.

### Modified: `extension/scripts/i18n/tests/test_nllb_wiring.py`

Migrated all NLLB references to Qwen equivalents (`_nllb_fetch` → `_qwen_fetch`, `_nllb_active_for` → `_qwen_active_for`, `SAROPA_SKIP_NLLB` → `SAROPA_SKIP_QWEN`, `primary="nllb"` → `primary="qwen"`). Removed `TestNllbMask` and `TestNllbFetch` classes (tested deleted masking code). 13 tests pass.

### Modified: `extension/scripts/i18n/tests/test_mt_provenance_modes.py`

Updated function references and provenance assertions from NLLB to Qwen. 12 tests pass.

### Modified: `extension/scripts/i18n/tests/test_progress.py`, `test_report_path.py`

Updated `_primary_engine` mock and report filename. 8 tests pass.

### Bug fix: `/no_think` leakage in `ar.json`

Three Arabic locale strings contained the literal Qwen3 chat directive `/no_think` appended to their translations (from the aborted initial run). Stripped from the locale file and added a regex strip in `qwen_engine._call_ollama()` to prevent recurrence.

### Locale files: 24 locales updated

All `extension/src/i18n/locales/*.json` and `extension/package.nls.ar.json` updated with translations from the gap-fill run. `locale_coverage.json` shows 0 missing across all 25 locales.

## Verification

- 33 Python unit tests pass (wiring: 13, provenance: 12, progress: 6, report: 2).
- `locale_coverage.json`: 0 missing strings across all 25 locales.
- No `/no_think` occurrences remain in any locale file.

## Finish Report (2026-07-29)

The NLLB→Qwen migration replaces a broken translation engine with the canonical Saropa MT engine. The legacy `nllb_engine.py` module is retained for its standalone tests but is no longer imported by any production code path. The `SAROPA_SKIP_QWEN=1` env var replaces `SAROPA_SKIP_NLLB=1` for forcing Google-only mode. Existing NLLB/Google translations are promoted to the Qwen cache keyspace on first access; a future `--mode upgrade` run will re-translate all low-quality provenance strings through Qwen.

### Known gaps

- `qwen_engine.py` has no dedicated unit test file; circuit breaker, stall detection, GPU ladder, and prompt construction are tested only indirectly through mocked boundaries.
- `_kill_all_ollama()` in `restart_ollama` terminates all system-wide Ollama processes — not scoped to the translation session.
- Module-level `_select_qwen_model()` runs `nvidia-smi` on every `import qwen_engine`, even when Qwen is skipped.
- `long_inputs()` and `reset_long_inputs()` in `qwen_engine.py` are dead stubs with no callers.

# i18n pipeline: deferred Qwen/Ollama provisioning

The extension's translation-generation pipeline (`extension/scripts/i18n/`) resolved the primary machine-translation engine unconditionally at the start of every run, before checking whether any locale actually had untranslated strings. Resolving the primary engine self-provisions Qwen/Ollama — starting the daemon subprocess and, on first use, pulling a multi-GB model — so a fully-cached run that needed to translate nothing still paid that cost.

## Root cause

`describe_engine_availability()` in `generate_locales.py` was printed unconditionally before the per-locale loop, and `_iter_pending_texts` / `count_pending_translations` / `prefetch_machine_translations` in `mt_fallback.py` each called `_primary_engine(locale)` eagerly at the top of the function — before checking whether any string in the locale actually lacked a cached translation. `_primary_engine()` → `_qwen_active_for()` → `qwen_engine.qwen_model_available()` triggers Ollama self-provisioning as a side effect of merely asking "which engine would this locale use."

## Fix

- `mt_fallback.py`: `_iter_pending_texts` now probes `cache_lookup_any()` (covers the qwen/nllb/google cache keyspaces) for each string first, and only resolves `_primary_engine(locale)` once it hits a string that is genuinely uncached under every engine. The resolved engine is memoized locally for the remainder of that locale's iteration.
- `count_pending_translations` no longer has its own eager engine check — it relies entirely on the lazy generator.
- `prefetch_machine_translations` builds the full pending list before resolving the primary engine, so an empty pending list never triggers engine detection.
- `generate_locales.py`: the `describe_engine_availability()` announcement is deferred behind an `engine_announced` flag, printed only the first time a locale in the per-locale loop is found to have `pending != 0`.

`prune_low_quality` / `prune_all` (upgrade/all modes) and the `--show`/`--set`/`--unset` key-management subcommands still resolve the engine eagerly — those paths are explicit user intent to re-translate or inspect a specific cache key, so provisioning there is expected and out of scope for this fix.

## Verification

Added `TestLazyEngineDetectionOnFullyCachedLocale` to `extension/scripts/i18n/tests/test_nllb_wiring.py` — four tests asserting `_primary_engine` is never called when every string is already cached (across `_iter_pending_texts`, `count_pending_translations`, `prefetch_machine_translations`), and that it resolves exactly once when a genuine gap exists. Full suite: 89/92 passing; the 3 pre-existing failures reference `_nllb_fetch`, a symbol removed in an earlier NLLB→Qwen migration, unrelated to this change.

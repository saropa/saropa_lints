# Translation generator: Ctrl-C finished the whole in-flight locale before exiting

Pressing Ctrl-C during a translation run (`generate_translations.py` →
`generate_locales.py`) printed "Stop requested — finishing the current string,
saving, then exiting", but the process then kept making live NLLB/Google calls
for every remaining untranslated string in the locale that was in flight,
completing that locale in full before the loop finally broke. To the operator
this read as "cancel never ends": the visible progress bar stopped, yet the run
continued working silently for dozens of strings.

## Root cause

The cooperative-cancel flag (`mt_fallback._stop_requested`, set by
`request_stop()`) was honored in exactly two places:

- the prefetch loop (`prefetch_machine_translations`), which breaks between
  strings, and
- the per-locale loop in `generate_locales.run`, which breaks between locales.

It was NOT honored in `_translate_one`, the single-string live-call path. After
prefetch broke for the in-flight locale, `generate_locales` still ran its
per-leaf mapping pass — `{s: translator.translate_text(s) for s in sorted_unique}`
— which calls `HybridTranslator.translate_text` → `machine_translate` →
`_translate_one` for every distinct source string. Strings already warmed by
prefetch resolved from cache, but every not-yet-cached string in that locale
triggered a fresh (slow) live MT call. So the stop request halted only the
visible prefetch, while the locale silently finished via the mapping pass.

## Fix

`_translate_one` (`extension/scripts/i18n/mt_fallback.py`) now checks
`stop_requested()` immediately after the clean-cache lookup and before any live
fetch. When a stop is pending:

- a clean cached entry is still served (already-paid work is never discarded);
- an uncached string returns the English source unchanged, with no live call and
  no cache write, so it remains a gap the next run resumes and fills.

Placement matters: the guard sits after the clean-cache branch (so warmed work is
still returned) and before the MT-env check and the NLLB/Google fetch calls (so
no fresh network/model work starts). The skipped string is intentionally not
recorded in the engine-mix or NLLB-fallback tallies — it was cancelled before any
engine attempted it, so attributing it to "english" would misreport it as a
string NLLB could not translate.

Because the guard short-circuits only when `stop_requested()` is true, normal
runs are byte-for-byte unchanged.

## Behavioral consequence

After a single Ctrl-C the run now exits within at most one in-flight string. The
interrupted locale shows as partial in the end-of-run audit (the honest state of
a cancel) rather than silently reaching full coverage and reporting the *next*
locale as the interruption point.

## Verification

- `python extension/scripts/i18n/tests/test_mt_provenance_modes.py` — 12 tests
  pass, including two added cases:
  - `test_translate_one_skips_live_call_for_uncached_when_stopped` — asserts an
    uncached string returns the source, neither `_nllb_fetch` nor `_google_fetch`
    is called, and no cache entry is written.
  - `test_translate_one_still_serves_clean_cache_when_stopped` — asserts a clean
    cached entry is still served after a stop with no live fetch.
- `python extension/scripts/i18n/tests/test_nllb_wiring.py` — 18 tests pass (no
  regression in the `_translate_one` engine/cache/provenance paths).
- `python extension/scripts/i18n/tests/test_progress.py` — 6 tests pass.
- `python -m py_compile extension/scripts/i18n/mt_fallback.py` — clean.

Tests run under the standard CPython 3.14 interpreter
(`D:\Tools\Python\Python314\python.exe`). No translation pipeline was executed;
the NLLB/Google fetch boundaries are stubbed in the tests.

## Scope

Developer translation tooling only (Python under `extension/scripts/i18n/`). No
change to the published lint package, the Dart analyzer plugin, or any extension
runtime/UI. Changelog entry recorded under the Unreleased Maintenance section.

## Files changed

- `extension/scripts/i18n/mt_fallback.py` — cancel guard in `_translate_one`.
- `extension/scripts/i18n/tests/test_mt_provenance_modes.py` — two new stop-flag
  tests.
- `CHANGELOG.md` — Unreleased Maintenance bullet.

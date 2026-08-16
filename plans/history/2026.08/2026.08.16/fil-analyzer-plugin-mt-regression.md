# Fix: Filipino "Analyzer plugin" MT regression + dictionary drift guard

The Filipino translation of "Analyzer plugin" → "Plugin ng analyzer" was repeatedly overwritten by the machine-translation pipeline, which returned the English string unchanged because both words are technical loanwords. Each MT run clobbered the manual fix. A structural guard was added to prevent the same class of regression for any curated dictionary entry.

## Finish Report (2026-08-16)

### Root cause

The `HybridTranslator` checks three sources in priority order: curated dictionary (`dictionaries.py`), MT cache, fresh MT. The Filipino locale had no curated entry for "Analyzer plugin", so every `generate_locales.py` run hit the MT engine, which returned the English verbatim, and the pipeline wrote that back to `fil.json`.

### Fix (immediate)

Added `"Analyzer plugin": "Plugin ng analyzer"` to the `fil` section of `extension/scripts/i18n/dictionaries.py`. Curated dictionary entries are checked first and are never overwritten by any `--mode` (`gaps`, `upgrade`, `all`). The provenance system (`mt_provenance.json`) also protects `"manual"` entries from re-translation, but the dictionary is the stronger guarantee — it does not depend on cache state.

### Fix (structural — dictionary drift guard)

Added `_check_dictionary_drift()` to `generate_locales.py`. Runs at the start of every translation or audit run, before any MT work. Compares every curated dictionary key against the current English source strings from `en.json` and `package.nls.json`. If a key no longer matches any source (e.g., the English wording was renamed), it prints a warning with the locale, orphaned key, and its now-unused translation.

Only flags entries where the translation differs from the key — curated passthroughs (English == translation) are harmless even when orphaned and are excluded.

On first run, the guard immediately surfaced 9 pre-existing orphaned entries across `nl`, `fr`, `ur`, `bn`, `fil`, and `he` — confirming the class of bug was not limited to the Filipino "Analyzer plugin" case.

### Files changed

| File | Change |
|------|--------|
| `extension/scripts/i18n/dictionaries.py` | Added curated Filipino entry for "Analyzer plugin" |
| `extension/scripts/i18n/generate_locales.py` | Added `_check_dictionary_drift()` function + call site |
| `extension/src/i18n/locales/fil.json` | Corrected `analyzerPlugin` value |
| `extension/src/i18n/locale_coverage.json` | Updated `fil` missing count 1 → 0 |
| `CHANGELOG.md` | Added maintenance entries |

### Scope

Scripts and generated locale files only. No Dart lint rules, no TypeScript extension code, no tests affected.

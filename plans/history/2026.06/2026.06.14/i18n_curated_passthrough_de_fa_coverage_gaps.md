# Curated passthrough entries close the last two extension i18n coverage gaps

The extension translation audit reported two strings as "missing" — German `activation.depsSorted` (`{detail} in {sections}`) and Persian `main.brandPrefix` (`Saropa Lints: {message}`). Both came back from the machine-translation pass identical to their English source, which the audit treats as a gap. Neither string has translatable content: the German value is two placeholders joined by the preposition "in" (spelled identically in German), and the Persian value is the Saropa brand (never translated) followed by a colon and a `{message}` placeholder. Without an explicit curated entry, the `--fail-on-missing` publish gate would block a release on two strings that are already rendering correctly.

## Finish Report (2026-06-14)

### Scope

(C) docs/scripts — the change is limited to the extension i18n dictionary tooling (`extension/scripts/i18n/dictionaries.py`) and the changelog. No Dart lint rules, analyzer plugin code, `en.json` keys, or generated locale catalogs were touched.

### Change

Two curated passthrough entries were added to `dictionaries.py`, each with a one-line comment naming why English is the correct rendering:

- Under the `de` table: `"{detail} in {sections}": "{detail} in {sections}"` — two placeholders plus the German preposition "in", which is spelled identically to English; no translatable words remain.
- Under the `fa` table: `"Saropa Lints: {message}": "Saropa Lints: {message}"` — brand name plus colon plus a `{message}` placeholder; nothing translatable remains.

The audit classifier (`generate_locales.py`, `_locale_stats`) categorizes a string whose output equals its source as *translated* when a dictionary entry explicitly maps it to itself (`dict_table.get(src) == src`), *skipped* when it is trivially untranslatable (single letter / punctuation / pure placeholder), and *missing* otherwise. These two strings carry a real word ("in") and brand text, so they fell through to *missing* until the curated entries were added. The entries match the established passthrough convention already used throughout the file for cognates, abbreviations, and brand-prefixed titles.

The locale JSON catalogs (`de.json`, `fa.json`) already held the correct English-identical text, so no catalog edit and no machine-translation run was required.

### Verification

- `py -3 -c "import ast; ast.parse(...)"` on `dictionaries.py` — valid Python syntax.
- `py -3 scripts/i18n/generate_locales.py --mode audit` (read-only; invokes no MT) — `de` and `fa` both report 0 missing (`de` 1432 translated / 5 skipped, `fa` 1431 translated / 6 skipped). The active seven-locale set (`ar`, `bn`, `de`, `es`, `fa`, `fil`, `fr`) is back to 0 missing.
- `py -3 -m unittest test_mt_fallback test_nllb_wiring test_report_path` in `extension/scripts/i18n/tests` — 38 tests pass. A test-directory grep for the changed strings and symbols found only an unrelated import comment; no assertion pinned these dictionary values.

### Out of scope / not changed

The audit also lists non-active locales (`he`, `hi`, `id`, `it`, `ja`, `ko`, `nl`, `pl`, `pt`, `ru`, `sw`, `th`, `tr`, `uk`, `ur`, `vi`, `zh`) with ~225 missing each. Those are outside the active shipping set and unrelated to this change; they were left untouched.

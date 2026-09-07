# i18n COGNATES approval list for cross-locale identical strings

The i18n translation audit flagged `"Source"` as missing in French, despite
"Source" being a valid French word with the same spelling and meaning. The
root cause: `compute_stats()` in `generate_locales.py` treats any output
identical to the English source as "missing" unless the curated dictionary
has an explicit `"X": "X"` passthrough. Previously, each cognate required a
separate per-locale entry scattered across `dictionaries.py` (65 such entries
existed).

## Finish Report (2026-09-07)

### Changes

- **`extension/scripts/i18n/dictionaries.py`**: Added `COGNATES` dict mapping
  English strings to lists of locale codes where the word is a valid cognate or
  loanword. A merge loop at import time injects `"X": "X"` passthroughs into
  each listed locale's `TRANSLATIONS` dict via `setdefault`, so curated entries
  still take priority. Seeded with three entries: `"Source"` (de/fr/nl),
  `"Status:"` (de/id/nl/pl/pt), `"{detail} in {sections}"` (de/it). A
  `ValueError` is raised at import time if any locale code is not a key in
  `TRANSLATIONS`.

- **`extension/scripts/i18n/generate_locales.py`**:
  - Imported `COGNATES` from `dictionaries`.
  - Updated the coverage-gate failure message to name both `COGNATES` and
    `DO_NOT_TRANSLATE` as fix paths.
  - Added `_check_cognate_drift()`: warns (or fails with `--fail-on-drift`)
    when a `COGNATES` key no longer matches any English source string.
  - Added `_validate_cognates()`: checks for conflicts (a locale already has a
    different translation for the string) and redundancies (overlap with
    `DO_NOT_TRANSLATE`).
  - Added `--check-cognates` CLI flag that runs `_validate_cognates()` and
    exits non-zero on any issue.

- **`CHANGELOG.md`**: Added Internal bullet for the `COGNATES` list.

### Validation

- `generate_locales.py --mode audit` reports 0 missing translations across all
  24 locales. The `fr` locale's `"Source"` string is counted as translated via
  the `COGNATES` merge.
- `generate_locales.py --mode audit --check-cognates` reports
  `✓ COGNATES: all entries valid, no conflicts.`

### Design decisions

- Existing per-locale passthroughs (65 entries) were left in place rather than
  bulk-migrated. They are harmless duplicates (`setdefault` is a no-op when the
  key already exists) and can be migrated incrementally.
- `mt_fallback.py` `_accept()` was not changed. Cognates in `TRANSLATIONS` are
  already skipped by `_iter_pending_texts` (line 883: `text in dict_table`),
  so MT is never consulted for them.
- The `--check-cognates` flag is opt-in (not wired into the publish pipeline by
  default) because the import-time `ValueError` already catches the most
  dangerous error (invalid locale codes), and the drift check runs
  unconditionally.

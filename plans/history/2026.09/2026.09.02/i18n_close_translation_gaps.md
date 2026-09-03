# Close i18n Translation Gaps

The i18n translation audit reported 10 missing translations across 6 locales (de, fil, id, it, nl, pl, pt). These strings fell through the MT pipeline because they are cognates, technical loanwords, or short labels that MT engines return unchanged — triggering the coverage gate's "identical to English" detector.

## Finish Report (2026-09-02)

### Problem

The `generate_translations.py` audit flagged 10 gaps where the translated output matched the English source with no dictionary entry acknowledging the match as intentional:

- **`Status:`** — identical in de, id, nl, pl, pt (5 locales × 1 string = 5 gaps)
- **`Debug`** — identical in it (1 gap)
- **`Debug Panel`** — fil (1 gap)
- **`LSP Server`** — fil (1 gap)
- **`Log`** — fil (1 gap)
- **`Saropa: Audit Folder...`** — fil (1 gap)

During regeneration, a new gap surfaced:

- **`idle`** — sw (1 gap, Qwen returned English unchanged)

### Fix

Added 11 dictionary entries to `extension/scripts/i18n/dictionaries.py`:

| Locale | Key | Value | Type |
|--------|-----|-------|------|
| de | `Status:` | `Status:` | curated passthrough (cognate) |
| id | `Status:` | `Status:` | curated passthrough (cognate) |
| nl | `Status:` | `Status:` | curated passthrough (cognate) |
| pl | `Status:` | `Status:` | curated passthrough (cognate) |
| pt | `Status:` | `Status:` | curated passthrough (cognate) |
| it | `Debug` | `Debug` | curated passthrough (tech loanword) |
| fil | `Debug Panel` | `Panel ng Debug` | manual translation |
| fil | `LSP Server` | `LSP Server` | curated passthrough (protocol acronym) |
| fil | `Log` | `Log` | curated passthrough (tech loanword) |
| fil | `Saropa: Audit Folder...` | `Saropa: I-audit ang Folder...` | manual translation |
| sw | `idle` | `tulivu` | manual translation |

### Verification

Final audit: 0 missing across all 24 locales, 100% coverage. The generate_translations script committed regenerated locale files in three auto-commits.

### Hardening: Swahili translation consistency

The initial `sw` translation for `"idle"` was `"haina shughuli"` (two-word phrase: "has no activity"). Audit of sibling status labels in `sw.json` showed they use single-word forms (`"kukimbia"`, `"mpona"`, `"kuanza"`). Corrected to `"tulivu"` (calm/idle) to match the terse pattern.

### Misroute fixed

The initial edit for the `de` `Status:` passthrough landed in the `es` (Spanish) section due to an ambiguous anchor (`"▾": "▾",\n    },\n    "it": {` matched `es`'s closing before `it`'s opening). Detected by querying `TRANSLATIONS['de']` at runtime; corrected by moving the entry to the actual `de` section boundary.

### Misroute prevention: locale-integrity validator

Added `_check_dictionary_locale_integrity()` to `generate_locales.py`. The function parses `dictionaries.py` via AST to extract which locale section each entry belongs to structurally, then compares against the runtime `TRANSLATIONS` dict. A mismatch means an edit placed an entry in the wrong locale's block. The check runs as a hard gate at the start of every `generate_translations.py` invocation — a misroute now fails the pipeline before any locale files are written.

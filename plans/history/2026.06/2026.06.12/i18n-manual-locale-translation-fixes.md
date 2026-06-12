# i18n Manual Locale Translation Fixes

A translation-coverage audit across the VS Code extension's seven non-English UI
catalogs reported 48 strings (out of 1191 per locale) where the locale value was
still identical to the English source. Each such string is one of three things:
a genuine localization defect (a label stranded in English while its sibling was
translated), an acronym or code-format token that is correct as English, or a
cognate spelled identically in the target language. The audit cannot tell these
apart — any identical output is flagged — so the gate stayed red on strings that
were already correct, while two real half-localized pairs sat unnoticed beside
them. The fix resolves all 48 without invoking the machine-translation pipeline.

## Finish Report (2026-06-12)

### Scope

VS Code extension localization only. Six locale catalogs under
`extension/src/i18n/locales/` (`de`, `es`, `fa`, `fil`, `fr`, `bn`), the curated
phrase dictionary `extension/scripts/i18n/dictionaries.py`, and `CHANGELOG.md`.
No Dart, no analyzer rules, no `en.json` source keys.

### Classification approach

Every flagged string was decided from the locale's own in-file precedent — the
rendering of sibling keys already in the same catalog — rather than from a fresh
translation guess. Two outcomes:

1. **Real translation** (9 strings) — written directly into the locale catalog
   and pinned in the dictionary so a future regeneration reproduces them exactly.
   These were genuine defects: a label left in English next to a translated
   partner. The review-status control localizes `reviewApplicable` in every
   locale but left its partner `reviewNotApplicable` ("N/A") in English; it now
   carries the negation of the translated sibling — Persian `قابل اجرا نیست`,
   Bengali `প্রযোজ্য নয়`, Filipino `Hindi naaangkop`. The Persian package
   `VERSION` section header was the only Latin-script header among otherwise
   Persian headers; it becomes `نسخه` (the word already used by the sibling
   version links). The French package links heading `Links` becomes `Liens`. The
   documentation quality badge `+docs` localizes to match the already-translated
   sibling badges (`+pruebas`/`+essais`/`+mga pagsubok`): Spanish `+documentos`,
   French `+documentation`, Filipino `+mga dokumento`.

2. **Curated passthrough** (39 strings) — recorded in the dictionary as
   `"X": "X"` with an explanatory comment. These are acronyms (`WASM`, `PR`),
   code/format badges (`dev`, `({rating}/10 bloat)`), and cognates spelled
   identically in the target language (French `Documentation`/`Excellent`/
   `Dimensions`/`Suggestions`, Spanish `No`, German `Repository`/`Upgrade`/
   `Links`/`Version`). English is the correct rendering. The audit's
   `compute_stats` credits a `dict[src] == src` entry as translated, so these
   clear the gate honestly without fabricating target-language text. Filipino
   section headers `ALERTS`/`VERSION`/`README IMAGES`/`DIRECT DEPS` are kept
   English as passthroughs, matching the catalog's existing values and the
   Filipino technical register; these are the one set where translating was
   arguable and was deliberately not done absent an in-file precedent.

### Why the pipeline was not run

`extension/scripts/generate_translations.py` drives the NLLB machine-translation
engine. Regenerating from the new dictionary entries would reproduce the same
catalog values this change writes by hand, but executing that pipeline is
prohibited. The manual catalog edits are the equivalent output; the dictionary
entries ensure the next sanctioned regeneration stays consistent.

### Verification

The audit's coverage gate logic (`compute_stats` in
`extension/scripts/i18n/generate_locales.py`) was reproduced offline against the
edited catalogs and dictionary: all 48 previously-missing strings now classify
as translated (9 via differing catalog values, 39 via curated passthrough), and
the missing count for the six affected locales is 0. The live
`--fail-on-missing` publish gate reads the same two inputs and therefore passes
without re-running MT. `dictionaries.py` imports cleanly; the dictionary-loading
unit test (`extension/scripts/i18n/tests/test_mt_fallback.py`, 18 cases) passes.
No test pinned any catalog value or dictionary entry that changed.

### Files

- `extension/src/i18n/locales/fa.json` — `VERSION`→`نسخه` (two section
  headers), `N/A`→`قابل اجرا نیست`.
- `extension/src/i18n/locales/bn.json` — `N/A`→`প্রযোজ্য নয়`.
- `extension/src/i18n/locales/fil.json` — `N/A`→`Hindi naaangkop`,
  `+docs`→`+mga dokumento`.
- `extension/src/i18n/locales/fr.json` — `Links`→`Liens`,
  `+docs`→`+documentation`.
- `extension/src/i18n/locales/es.json` — `+docs`→`+documentos`.
- `extension/src/i18n/locales/de.json` — no value change (all eight flagged
  strings are passthroughs handled in the dictionary).
- `extension/scripts/i18n/dictionaries.py` — 48 curated entries across the
  `de`/`es`/`fr`/`fa`/`fil`/`bn` blocks (9 pinned real translations, 39
  passthroughs), each under a dated explanatory comment.
- `CHANGELOG.md` — `### Fixed (Extension)` entry under `[Unreleased]`.

### Outstanding

Filipino section headers remain English by design (see above) and can be
localized later if an in-file precedent or a competent reviewer establishes the
idiomatic all-caps forms.

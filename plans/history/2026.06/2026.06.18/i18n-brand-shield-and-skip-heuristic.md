# i18n: shield "Drift Advisor" brand + skip non-translatable brand strings

The extension's machine-translation pipeline was transliterating the "Drift Advisor"
product name into local scripts across locales, and its coverage audit perpetually
flagged two brand-plus-placeholder strings as Missing because MT can only echo them.
Both are i18n tooling defects in `extension/scripts/i18n/mt_fallback.py`; neither
changes any Dart lint rule.

## Finish Report (2026-06-18)

### Defect 1 — brand name transliterated

The MT shield protects do-not-translate terms via the `_DO_NOT_TRANSLATE` tuple in
`mt_fallback.py` (each term masked with an ASCII sentinel before translation and
restored after, so the engine cannot touch it). "Drift Advisor" — a product/brand
name with one spelling worldwide — was absent from that tuple, so NLLB/Google were
free to translate or transliterate it in every locale that contains a string such as
`Drift Advisor is not connected. Click Refresh after starting the server.` or
`Show live Drift issues (Drift Advisor)`.

Fix: `"Drift Advisor"` was added to `_DO_NOT_TRANSLATE`, grouped with the other
product names. The existing cache validator (`_cache_value_is_clean` /
`_cache_acceptable`) already rejects any cached value missing a verbatim
do-not-translate term, so previously transliterated entries self-heal on the next
regeneration — no manual cache purge is required.

### Defect 2 — non-translatable strings counted as Missing forever

`should_skip_machine_translate` skipped strings that are pure brand, pure
placeholder, punctuation-only, or a single-letter label wrapping a placeholder. It
did not cover strings composed of brand terms PLUS `{placeholders}` PLUS separators,
e.g. `Saropa Lints: {message}` (locale `ur`) and `Saropa Lints {label}: {from} → {to}`
(locale `zh`). After the shielded brand and the `{tokens}` are removed, only
punctuation/whitespace remains, so MT echoes the source unchanged — and the audit
counts an unchanged result as Missing. These two strings therefore showed as
coverage gaps on every run despite having nothing to translate.

Fix: a new branch in `should_skip_machine_translate` strips the brand terms and the
placeholders, then skips the string when no alphanumeric character (in any script)
remains. The gate is alphanumeric-presence based, so a real word adjacent to the
brand (e.g. `Saropa Lints Dashboard`, `{count} Saropa packages`) still leaves a
letter and is correctly translated.

### Tests

`extension/scripts/i18n/tests/test_mt_fallback.py` gained
`test_skips_brand_plus_placeholders_and_separators` (pins both `ur`/`zh` strings as
skipped) and two additional cases in `test_does_not_skip_real_phrases`
(`Saropa Lints Dashboard`, `{count} Saropa packages`) guarding against over-skip.
Full file: 19/19 pass via `python extension/scripts/i18n/tests/test_mt_fallback.py`.

### Follow-up not performed here

The translated locale catalogs and the live coverage gate only reflect both fixes
after the NLLB/Google regeneration pipeline is re-run, which is operator-initiated
(`extension/scripts/generate_translations.py`); it was not executed as part of this
change. The brand fix heals affected strings on that run; the skip fix moves the two
`ur`/`zh` gaps from Missing to Skipped on the next audit.

# i18n: Skip placeholder-only template strings in translation

The translation pipeline's `should_skip_machine_translate()` function already skipped pure `{placeholder}` strings and single-letter-plus-placeholder patterns, but missed strings where placeholders were separated by punctuation and whitespace (e.g. `{category} ({count})`, `{symbol} ({count})`). These strings contain zero translatable words — MT can only echo or corrupt them — yet they were sent to the translation engine and then flagged as "missing" when the output matched the input.

## Finish Report (2026-08-07)

**Defect:** `should_skip_machine_translate()` lacked a general check for strings whose entire non-placeholder content is punctuation/whitespace. The existing pure-placeholder regex (`(\{[A-Za-z0-9_]+\})+`) required placeholders to be adjacent with no separators. The brand+placeholder check handled this pattern but only when a brand term was also present.

**Fix:** Added a new check in `extension/scripts/i18n/mt_fallback.py` (lines 513–517): after stripping `{placeholder}` tokens, if no alphanumeric characters remain in the residue, the string is classified as untranslatable and copied verbatim. The `residue` computation was hoisted above this new check so both the new check and the existing single-letter-label check share one computation.

**Test changes:** Added `test_skips_placeholder_punctuation_only` covering `{category} ({count})`, `{symbol} ({count})`, `{a} / {b}`, `{x}-{y}`. Updated `test_does_not_skip_ascii_symbol_placeholder` → `test_skips_ascii_symbol_placeholder`: strings like `* {count}` have no translatable content (punctuation + placeholder) and are now correctly skipped.

**Impact:** Eliminates 48 false-positive missing-translation reports (2 per locale × 24 locales). The remaining 1 genuine gap (`Homepage` in `fil`) is unaffected — it contains a real English word that needs translation.

**Files changed:**
- `extension/scripts/i18n/mt_fallback.py` — new skip check
- `extension/scripts/i18n/tests/test_mt_fallback.py` — new + updated tests
- `CHANGELOG.md` — maintenance entry

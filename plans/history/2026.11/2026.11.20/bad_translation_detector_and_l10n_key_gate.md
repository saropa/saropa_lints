# Bad-translation detector and l10n key gate

Machine-translated locale catalogs shipped mechanically defective strings (leaked shield sentinels, `⁇` glyphs, prompt echo, wrong script, hallucinated continuations) and nothing detected or removed them. The l10n key/param checker existed but was not enforced in CI.

## Finish Report (2026-11-20)

### Changes
- `extension/scripts/i18n/bad_translations.py` (new): pure `detect()` shared by CLI (`--check`, `--purge`, `--out`), CI check, and cache auto-prune. Hard classes (auto-deletable): empty, leak, placeholder drift, wrong-script (prose of 2+ words with no locale-script characters), blowup, blocklist. Soft (report only): `verify_locales.suspicious`.
- `extension/scripts/i18n/bad_translations_blocklist.json` (new): domain-term mistranslation seeds.
- `extension/scripts/i18n/generate_locales.py`: calls `prune_bad_cache_entries` per locale before pending-count; audit mode does not prune.
- `extension/scripts/i18n/mt_fallback.py`: `_SHIELD_RESIDUE_RE` now matches bare `ZZ`, `_PH<n>_`, `ПХ<n>`; new `_has_residue(text, candidate)` excuses tokens that the English source itself contains. `_accept` uses it.
- `.github/workflows/ci.yml`: job `extension-manifest-nls` runs `check_l10n_keys.py --check-params`.
- `// l10n:passthrough` markers on variable-param l10n calls in `engineCardsHtml.ts`, `orphanPreflight.ts`, `blast-radius-attacher.ts`, `projectMapShell.ts` (checker false positives).
- `CHANGELOG.md`: three `### Internal` bullets.

### Review findings applied
- Wrong-script flag fired on a lone acronym kept in Latin; now requires 2+ words.
- Leak excuse compared `_PH2_` against English `PH2`; now strips underscores.
- Write-time residue rejection ignored legitimately present tokens; now excused via `_has_residue`.

### Hardening and follow-up
- `--purge` copies the cache to `mt_strings.json.bak` before deleting.
- `tests/test_bad_translations.py` gained prune tests (clean kept, defective removed, manual and dictionary entries protected).
- Sampled 16 hard flags (wrong-script, blowup, blocklist, placeholder): 16 true positives. Leak class (2008 of 2241 hard) spot-checked earlier only.
- `extension/scripts/i18n/semantic_check.py` (new, report only): embedding-similarity review queue. Pure logic tested (5 pass); never run against a live Ollama server (server was down), so end-to-end behavior and precision are unverified. Collects 2306 de pairs.

### Verification
- `tests/test_bad_translations.py`: 14 pass. `tests/test_mt_fallback.py`: 29 pass. `generate_locales` imports.
- `check_l10n_keys.py --check-params`: exit 0, 1874/1874 literal keys resolve.
- Shipped-locale scan: 2283 hard, 369 soft flags. False-positive rate unmeasured; the scan predates the review fixes above, so counts may drop slightly.

### Open
- `bad_translations.py --check` is not in CI or the publish gate (`scripts/modules/_extension_publish.py`); it exits 1 until the cache refill is run.
- Cache refill not run (user-triggered MT).
- Reported "Null check operator used on a null value" internal error: source unknown.

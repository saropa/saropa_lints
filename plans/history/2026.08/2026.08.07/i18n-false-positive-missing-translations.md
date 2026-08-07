# i18n: Resolve 71 false-positive missing translations

The i18n translation audit reported 71 missing translations across 24 locales, but all 71 were false positives: technical acronyms (`PID`, `RSS`), a computing term (`Daemon`), emoji+placeholder format strings, and a French cognate (`Action`).

## Finish Report (2026-08-07)

### Root cause

The MT pipeline's `should_skip_machine_translate()` function correctly skipped single-letter labels and pure-placeholder strings, but had no rule for:
- Short technical acronyms (3 uppercase letters like `PID`, `RSS`)
- Emoji/symbol-only prefixes followed by placeholders
- Computing terms that are universally kept in English

These strings passed through to the MT engine, which returned them unchanged (correctly), and the audit then flagged them as "missing" since output matched input.

### Changes

1. **`extension/scripts/i18n/mt_fallback.py`**
   - Added `Daemon`, `RSS`, `PID` to `_DO_NOT_TRANSLATE` tuple for mid-sentence shielding in longer translatable strings.
   - Added `_SKIP_EXACT` frozenset for O(1) exact-match skipping of standalone technical terms (`PID`, `RSS`, `Daemon`), checked before any regex runs.
   - Added skip rule for emoji/symbol + placeholder patterns, guarded by a non-ASCII requirement to prevent ASCII-only prefixes like `* {count}` from being silently skipped.

2. **`extension/scripts/i18n/dictionaries.py`**
   - Added `"Action": "Action"` passthrough to the `fr` locale dictionary (French cognate, identical spelling).

3. **`extension/scripts/i18n/tests/test_mt_fallback.py`**
   - Added `test_skips_exact_technical_terms` — verifies `PID`, `RSS`, `Daemon` are skipped.
   - Added `test_skips_emoji_placeholder_only` — verifies emoji+placeholder patterns are skipped.
   - Added `test_does_not_skip_emoji_with_words` — verifies strings with translatable text after emoji are NOT skipped.
   - Added `test_does_not_skip_ascii_symbol_placeholder` — verifies `* {count}`, `# {items}`, `+ {name}` are NOT skipped (non-ASCII guard).
   - Extended `test_does_not_skip_real_phrases` — added `"Kill Orphaned Flutter Daemons"` and `"Dart processes: {count} ({size} RSS)"` as false-positive guards.

4. **`CHANGELOG.md`**
   - Added maintenance entry under `[14.5.0]`.

### Verification

- All 27 `test_mt_fallback.py` unit tests pass (4 new, 1 extended).
- Locale regeneration ran (`--mode gaps`): 71 → 3 missing. The 3 remaining are genuine MT gaps (`total RSS` in bn/he, a kill-daemons string in ko) that need actual MT.
- Verified `Daemon`/`PID`/`RSS` appear in longer translatable strings — the `_DO_NOT_TRANSLATE` shielding protects them mid-sentence while surrounding text translates.
- Verified the emoji regex rejects ASCII-only prefixes (`* {count}`) via the non-ASCII guard.

### Coverage

| String | Count | Resolution |
|---|---:|---|
| `RSS` | 19 locales | `_SKIP_EXACT` + `_DO_NOT_TRANSLATE` |
| `PID` | 18 locales | `_SKIP_EXACT` + `_DO_NOT_TRANSLATE` |
| `⚠ {size}` | 18 locales | `should_skip_machine_translate` emoji regex |
| `🔴 {size}` | 11 locales | `should_skip_machine_translate` emoji regex |
| `Daemon` | 4 locales | `_SKIP_EXACT` + `_DO_NOT_TRANSLATE` |
| `Action` (fr) | 1 locale | Dictionary passthrough |
| **Total** | **71** | |

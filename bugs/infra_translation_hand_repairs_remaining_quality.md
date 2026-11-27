# Extension translations: remaining quality work

**Status: Open**

From `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.

Blocker: hand repair or an owner-approved run, plus native-speaker review.

## State

Locale parity tests: 49 passing, 0 failing after the hand repairs of 2026-11-26 and 2026-11-27 (written by an agent, not a native speaker, no MT engine).

- Fixed 2026-11-27: the 46 overlong values (40+ character English, more than 2.5 times as long) plus every leaked MT prompt and looped word or phrase, 387 values in all 24 locales. Repairs are in `extension/scripts/i18n/manual_translations_mt_leaks.py`, folded into `_REPAIRS`. The parity test and `bad_translations.py` now fail on a leaked numbered prompt, a word or phrase repeated three times in a row, or a 40+ character value over 2.5 times the English length.
- Fixed 2026-11-27 (owner-approved hand repair): 13,592 English sources in all 24 locales, in `extension/scripts/i18n/invented_repairs/<locale>.json`, folded into `_REPAIRS`. Pass 1 (invented sentences and nonsense labels): 9,057, of which about 2,000 invented sentence or clause, 5,190 nonsense label, 1,870 other wrong meaning in the same values. Pass 2 (every 1-4 word label ending in a full stop): 4,535, of which 1,735 garbled or invented, 407 wrong meaning, 2,393 only the stop or a sentence-style imperative. Includes fr `typePr` and ja `internalBadge`. 22 curated `dictionaries.py` entries were also wrong and are corrected there (18 ur values in Sindhi script; ur, bn, fil, he "Manage Rule Packs" naming a retired command). Class splits are approximate. `bad_translations.py --check` went from 947 hard flags to 0.
- Cause check of ed6b905f9 (de/es/ru/sw/fil): every changed value equals a `LEAK_REPAIRS` entry for its English source; there are no stray edits. Six of those values (de " run", five sw word-salad values) were repaired although the new guard did not flag them; the old values were nonsense, so they are not regressions.
- Guard added: 85 known invented phrases in `extension/scripts/i18n/invented_phrases.json` (each with an English excuse regex) and a back-to-back repeat check for Chinese, Japanese and Korean, in both the parity test and `bad_translations.py`.
- The guard cannot detect: a new invention in different words, inventions in ordinary phrasing (no ko phrases are listed for that reason), wrong labels that do not repeat, and plain mistranslation. Thai is not loop-checked (it doubles words legitimately).
- Still open: candidates were picked by heuristics (brand prefix, extra sentence, text after a placeholder, long, repeated or full-stop labels); other values, mainly medium and long sentences, were not all read and still hold mistranslations. The long sw memory, CI, hazard-scan and settings paragraphs still read as nonsense. Product names (Package Vibrancy, Code Health) are kept in English in some values and translated in others. Sindhi-script letters in ur are not checked by any guard. The fragment "Matches each command's" was reworded per locale without seeing how it joins the bold field names after it.
- Least confident languages: sw, fil, ur, bn (lowest-resource; MT text around the repairs is poor) and th. Uncertain terms in every locale: "analysis lane", "Mix charts", "Held", "stub-tested", "test drift", "Dormancy Signal".
- No translation from any hand repair has a native-speaker review.

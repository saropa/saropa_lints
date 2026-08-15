# Manual translation fix for MT fallback strings

Six extension i18n strings were served by the Google fallback engine because the primary MT engine (Qwen) declined to translate them, per `extension/reports/20260815/20260815_112625_i18n_mt_fallbacks.md`. One of the six (Swahili `config.property.scanOnSave.resolveTypes.markdownDescription`) had the fallback engine mistranslate the literal CLI flag `--resolve` into `--suluhisha`, corrupting a code-facing string embedded in user-facing markdown.

## Finish Report (2026-08-15)

**Files changed:**
- `extension/package.nls.de.json` — `config.property.enabled.markdownDescription`: rewritten for correct **on**/**off** bold-pairing (source only bolded "on") and to restore the code-literal backtick style around `saropa_lints` / `analysis_options`.
- `extension/package.nls.sw.json` — `config.property.scanOnSave.resolveTypes.markdownDescription`: rewritten; restores the literal `` `--resolve` `` flag (previously translated to `` `--suluhisha` ``) and fixes a markdown bold-marker space (`** imewashwa**` → `**imewashwa**`).
- `extension/src/i18n/locales/sw.json` — five `scanOnSave` strings rewritten: three (`statusBar.failed`, `scanOnSaveFailed`, `scanOnSaveDaemonBackoff`) for correct Swahili grammar (the fallback output used a bare infinitive verb as a subject, which does not parse as a sentence in Swahili), and two (`scanOnSaveDaemonBadResponse`, `scanOnSaveDaemonExited`) that were not translations at all — degenerate repetition-loop output from the MT model (a single word/phrase repeated hundreds of times), with `scanOnSaveDaemonExited` additionally ending in a leaked English fragment resembling a stray translation-run prompt artifact ("the user is asking for a list of 10000000000000000000000000000000"). Confirmed by cross-checking all 24 shipped locales that this corruption was isolated to Swahili.
- `extension/src/i18n/locales/fil.json` — reviewed, no change; the flagged Filipino string (`scanOnSave.statusBar.failed`) was already idiomatic.
- `extension/scripts/i18n/dictionaries.py` — added all 7 corrected strings (6 Swahili, 1 German) as curated `TRANSLATIONS` entries. The dictionary is checked before the MT cache in every mode (`gaps`/`upgrade`/`all`) and is git-tracked (unlike `.cache/mt_provenance.json`, which is gitignored and would not survive a fresh clone), so these corrections cannot be silently regenerated back to corrupted output by a future `generate_translations.py` run.
- `CHANGELOG.md` — one-line Maintenance entry under `[Unreleased]`.

**Verification:** `node -e "JSON.parse(...)"` confirmed valid JSON for all edited locale files; `python -m ast` confirmed `dictionaries.py` parses, and a runtime import confirmed all 7 new keys are present under the correct locale. No Dart code, no ARB files, and no `en.json` source keys were touched, so no catalog regeneration or analyzer sweep was required.

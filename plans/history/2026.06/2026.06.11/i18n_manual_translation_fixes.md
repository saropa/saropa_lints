# i18n Manual Translation Fixes

**Trigger:** User ran the i18n translation audit (`generate_translations.py` mode `[4] audit only`) and asked, in two passes, to "manually fix these translations" — first the genuinely-missing strings (English shipping in a non-English locale), then the low-quality set, scoped via AskUserQuestion to **"genuinely-weak only"** (curate only entries that are clearly wrong, in languages where the error is unambiguous). NLLB / any MT pipeline was deliberately not run (hard prohibition).

---

## Finish Report (2026-06-11)



### Scope

**(B)** VS Code extension i18n only — curated dictionary (`extension/scripts/i18n/dictionaries.py`) and locale catalogs (`extension/src/i18n/locales/*.json`), plus a CHANGELOG entry. No Dart lint rules, analyzer plugin, or `en.json` source keys were touched.

### What changed

**Batch 1 — four genuinely-missing strings (were shipping English in their locale):**

| Locale | Key | Value applied | Rationale |
|---|---|---|---|
| `hi` | `…downloadsCount` | `पिछले 30 दिनों में {count} डाउनलोड` | Mirrors the Bengali sibling phrasing (Latin numeral "30"). |
| `fil` | `deps.tooltipHeaderShared` | `{total} na transitive deps ({shared} na shared)` | Filipino convention: count + "na", technical nouns kept English. |
| `fil` | `version.sizeLabel` | `{label}: {size}` | True passthrough — only literal is `: `, identical in Filipino. |
| `sw` | `version.sizeLabel` | `{label}: {size}` | Same passthrough rationale (Swahili). |

**Batch 2 — one unambiguous, cross-locale defect in the low-quality set (the social-media noun "likes" rendered as the verb "to like"):**

| Locale | `version.likesCount` was (verb) | now (noun) |
|---|---|---|
| `de` | `{count} pub.dev mag` | `{count} pub.dev Likes` |
| `ar` | `{count} pub.dev يحب` | `{count} إعجاب على pub.dev` |
| `fa` | `{count} pub.dev لایک می کند` | `{count} لایک در pub.dev` |

`fil` `likesCount` ("gusto") was left — a defensible noun, not unambiguously wrong.

Every fix was applied in **two places**: a curated entry in `dictionaries.py` (durable — survives regeneration, and reclassifies the string from "low-quality (Google engine)" to "curated", clearing the audit flag) with a one-line "why" comment, plus the literal value in the locale JSON.

### Key finding (why the low-quality set was NOT mass-rewritten)

The ~350 "low-quality" flags are **not bugs and not shipping English** — they are already translated by the Google engine and flagged only because they are not NLLB output (the audit header calls them "upgrade candidates"; the flag is purely *engine ≠ NLLB*). A verification sample in `de.json` (`source`, `summaryFooter`, `topRulesOther`, `gradeTooltip`, `title`, `tooltipHeaderShared`) confirmed correct translations. The one unambiguous error class found was the "likes" verb mistranslation. Hand-rewriting the remaining flags across 20 languages would replace correct translations with unverifiable hand translations — a lateral move at best, a regression risk in unreviewable languages. The pipeline's intended upgrade path for those is NLLB mode `[2]`, which only the user runs.

### Deep review notes

- No logic/race/recursion surface — data + dictionary edits only.
- `dictionaries.py` validated with `ast.parse` (parses clean). All six edited JSON files validated with `json.load` (parse clean).
- New entries match the placement and shape of the hundreds of existing curated entries (alphabetical within each locale's `{...}` block; passthroughs carry an explanatory comment, same as the existing `{direct} direct, {transitive} transitive` passthrough).
- RTL note: `ar`/`fa` values place `{count}` then the noun then "on pub.dev" — correct reading order.

### Testing

**4A audit:** Grepped `extension/` (ts/mjs/js/py) for every touched key/value. The only test referencing them, `extension/src/test/vibrancy/views/report-html.test.ts`, pins **English** values from `en.json` (`title="1,234 pub.dev likes"`, `pub.dev likes not available`). `en.json` was **not** modified, so those assertions are unaffected. The Python i18n tests under `extension/scripts/i18n/tests/` cover engine/fallback/provenance mechanics, not dictionary content.

**Tests not executed in this environment** — audited by inspection only. The extension TS harness is heavy, and the Python `test_nllb_*` suites risk loading the NLLB model, which is hard-prohibited. No assertion drift identified.

### Coverage gate

The user's mode-`[4]` audit (run after Batch 1) reported **0 missing** for all 20 non-CJK locales including `hi`/`fil`/`sw`. Batch 2 touched low-quality (not missing) entries, so the missing count stays 0. `generate_locales.py` was **not** re-run, to avoid a gated cross-locale mass regeneration (and any MT invocation).

### Maintenance

- CHANGELOG: added a `### Fixed (Extension)` section under `[Unreleased]` (two bullets — the four filled strings, the three likes-verb corrections).
- README: verified — no updates needed (rule/doc counts unchanged).
- Roadmap / tiers / pubspec: not applicable (no Dart rule change).
- No `bugs/*.md` closed — task did not close a bug file.

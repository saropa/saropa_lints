# Plan: Add 15 Languages (Extension Locales 25 → 40)

## Goal

Add the next 15 highest developer-population languages to the VS Code extension's
localization, taking it from **25 → 40 languages**. Every target is already in
NLLB's FLORES-200 map, so this is **plumbing + catalog regeneration — no model
work**. Translation runs NLLB-primary (offline, high quality) with Google
fallback per string, exactly as the existing 24.

## Current state

24 locales + English base: `ar, bn, de, es, fa, fil, fr, he, hi, id, it, ja, ko,
nl, pl, pt, ru, sw, th, tr, uk, ur, vi, zh`.

## Target languages

Ranked by developer-population impact (India-heavy, where Flutter adoption is
strongest). All LTR — **no RTL handling needed**. Google codes verified against
`deep_translator.GoogleTranslator` targets; NLLB codes verified present in
`nllb_engine._NLLB_LANG_MAP`.

| # | Language | Locale | NLLB (FLORES-200) | Google fallback | Region / rationale |
|---|---|---|---|---|---|
| 1 | Telugu | `te` | `tel_Telu` | `te` | Hyderabad — top-3 Indian IT hub |
| 2 | Tamil | `ta` | `tam_Taml` | `ta` | Chennai + Sri Lanka + SG/MY diaspora |
| 3 | Marathi | `mr` | `mar_Deva` | `mr` | Pune & Mumbai tech hubs |
| 4 | Traditional Chinese | `zh-TW` | `zho_Hant` | `zh-TW` | Taiwan/HK; distinct script from `zh` |
| 5 | Kannada | `kn` | `kan_Knda` | `kn` | Bangalore — India's Silicon Valley |
| 6 | Romanian | `ro` | `ron_Latn` | `ro` | Large EU software-outsourcing base |
| 7 | Malay | `ms` | `zsm_Latn` | `ms` | Malaysia/Singapore/Brunei |
| 8 | Gujarati | `gu` | `guj_Gujr` | `gu` | Large business/dev population |
| 9 | Greek | `el` | `ell_Grek` | `el` | Established EU dev community |
| 10 | Czech | `cs` | `ces_Latn` | `cs` | Strong Central-European tech sector |
| 11 | Malayalam | `ml` | `mal_Mlym` | `ml` | Kerala — high-literacy IT services |
| 12 | Swedish | `sv` | `swe_Latn` | `sv` | Nordic tech (Spotify, Klarna, Ericsson) |
| 13 | Hungarian | `hu` | `hun_Latn` | `hu` | Budapest tech hub |
| 14 | Punjabi | `pa` | `pan_Guru` | `pa` | ~125M speakers, India/Pakistan |
| 15 | Finnish | `fi` | `fin_Latn` | `fi` | Nokia legacy, gaming/tech (Supercell) |

`zh-TW` is the only special case: it carries its own FLORES script tag
(`zho_Hant`, vs `zh` = `zho_Hans`) and its own Google code `zh-TW`. The runtime
already resolves `zh-TW` as a distinct catalog key.

## Touch-points (per locale — 4 code sites + 2 generated artifacts)

The locale list is currently duplicated across several files. Each new locale
must be added to **all** of these or it silently no-ops somewhere:

1. **`extension/scripts/i18n/generate_locales.py`** — append the codes to the
   default `--locales` string (the pipeline's source of which locales to build).
2. **`extension/scripts/i18n/mt_fallback.py`** — add each `locale: google_code`
   to `LOCALE_TO_GOOGLE`. **Without this the Google fallback is dead** for the
   locale: `_google_fetch` returns `None`, so any string NLLB bounces becomes
   English instead of a Google translation.
3. **`extension/src/i18n/runtime.ts`** — add `import xx from './locales/xx.json';`
   AND the `xx: xx as NestedRecord,` entry in the `catalogs` map. `normalizeLocale`
   needs no change (it keys off `catalogs`). `zh-TW` needs a valid JS identifier
   for the import binding (e.g. `import zhTW from './locales/zh-TW.json'`).
4. **`extension/scripts/i18n/dictionaries.py`** — optional. All 24 existing
   locales have curated `TRANSLATIONS` entries (55–136 each) for proper-noun
   passthroughs and quality fixes. New locales can start with **no** entry (pure
   MT; the brand is auto-shielded) and accrue curated entries iteratively as the
   coverage gate / review surfaces bad strings.

Generated artifacts (produced by the pipeline, not hand-written):

5. **`extension/src/i18n/locales/<code>.json`** — runtime catalog (from `en.json`).
6. **`extension/package.nls.<code>.json`** — manifest strings (from `package.nls.json`).
   VS Code auto-discovers these by filename; no `package.json` list to update.

## Implementation phases

### Phase 1 — Plumbing (code only, no translation run)

Add all 15 codes to sites 1–3 above. This is mechanical and identical per
locale. Acceptance:
- `tsc --noEmit` clean (runtime.ts imports resolve — the `.json` files won't
  exist yet, so create empty `{}` placeholders or generate first; see note).
- No locale code appears in fewer than all three of sites 1–3.

> Ordering note: `runtime.ts` statically imports each `locales/<code>.json`, so
> those files must exist before `tsc` passes. Either (a) generate the catalogs
> first (Phase 2) then wire `runtime.ts`, or (b) seed each `<code>.json` with
> `{}` and let Phase 2 overwrite. Option (a) is cleaner — wire sites 1–2, run
> Phase 2, then wire site 3.

### Phase 2 — Generate catalogs (NLLB-primary; operator-run)

Run the translation pipeline for the new locales (Python 3.14, NLLB):

```
D:\Tools\Python\Python314\python.exe extension\scripts\generate_translations.py --locales te,ta,mr,zh-TW,kn,ro,ms,gu,el,cs,ml,sv,hu,pa,fi
```

Per locale, watch the **`engines -> nllb:X, google:Y, english:Z`** line (added in
the robustness pass). A healthy run is mostly `nllb`. Heavy `google` on the Indic
scripts (te/ta/kn/ml/gu/pa/mr) would signal a placeholder-mask or load problem —
investigate before trusting output. This produces sites 5–6.

> This step is a machine-translation pipeline; it must be run by the operator,
> not automated unattended.

### Phase 3 — Verify + curate

- `tsc --noEmit` clean with the real catalogs.
- `npm run verify-nls-keys` — confirms each `package.nls.<code>.json` has the same
  key set as the English base.
- Coverage gate: `generate_locales.py --fail-on-missing` must report **0 missing**
  for every new locale (publish blocks otherwise). Any leftover gaps get a curated
  `dictionaries.py` entry (or an `"X": "X"` English-passthrough for proper nouns).
- Spot-check a handful of rendered strings per script family (one Indic, one
  Latin, Traditional Chinese, Greek) for obvious garbage — NLLB greedy decode can
  degenerate on 1–2 word labels even when the mask survives.

## Non-goals / out of scope

- No NLLB model changes (all 15 are in FLORES-200 already).
- No RTL work (all 15 are LTR).
- No new pipeline features — this rides the existing NLLB + Google fallback.
- Not consolidating the duplicated locale list into one source of truth (worth
  doing, but a separate refactor; flagged below).

## Risks & notes

- **Four-places-per-locale duplication** is the main footgun: miss
  `LOCALE_TO_GOOGLE` and the locale silently loses its Google fallback; miss the
  `runtime.ts` catalog entry and the locale renders entirely in English at
  runtime. A follow-up refactor to a single `SUPPORTED_LOCALES` source of truth
  (consumed by all four sites) would remove this class of error — recommended but
  not required for this task.
- **NLLB quality on short UI labels** (e.g. "Stars", "Likes") is the weakest spot
  across all locales, not specific to these 15; the engine-mix report makes any
  silent Google fallback visible.
- **Bundle size**: 15 more `locales/<code>.json` + `package.nls.<code>.json` files
  ship in the `.vsix`. Each is small (English-key-parity JSON), so the increase is
  modest, but it is a real bundle-size addition to note at publish.
- **Publish**: regenerated catalogs must be committed; the publish coverage gate
  (`--fail-on-missing`) enforces completeness.

## Verification checklist (definition of done)

- [ ] 15 codes in `generate_locales.py` default `--locales`
- [ ] 15 `LOCALE_TO_GOOGLE` entries
- [ ] 15 `runtime.ts` imports + `catalogs` entries
- [ ] `te,ta,mr,zh-TW,kn,ro,ms,gu,el,cs,ml,sv,hu,pa,fi` catalogs generated (sites 5–6)
- [ ] `tsc --noEmit` clean
- [ ] `npm run verify-nls-keys` clean
- [ ] `generate_locales.py --fail-on-missing` = 0 missing for all 15
- [ ] engine-mix report mostly `nllb` per locale (Google fallback not dominating)
- [ ] CHANGELOG entry under `### Changed (Extension)`

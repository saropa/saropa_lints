# i18n manual gap-fill — bn `downloadsCount`, fa `• {dep}`

The user ran `extension/scripts/generate_translations.py` (mode 2: gaps + upgrade low-quality to NLLB), interrupted it during the `fil` locale, and reported that two keys came back identical to English and "have to be manually translated." This task hand-fills those two catalog gaps without running any MT pipeline (a hard standing prohibition), and registers them in the curated dictionary so a future regen reproduces them instead of re-flagging.

## Finish Report (2026-06-10)

**Scope:** (B) VS Code extension i18n — locale catalog + curated translation dictionary. No Dart lint-rule / analyzer code touched.

### 1. Critical note
This work will be reviewed by another AI.

### 2. What changed and why
The interrupted MT run left two strings untranslated (output identical to English source):

| Locale | Key | Source English | Resolution |
|---|---|---|---|
| `bn` | `packageDashboard.cells.downloadsCount` | `{count} downloads in the last 30 days` | Hand-translated to `গত 30 দিনে {count} ডাউনলোড`, mirroring the sibling `downloadsUnavailable` phrasing (Latin "30") and the German reference `{count} Downloads in den letzten 30 Tagen`. |
| `fa` | `…tooltipDep` | `• {dep}` | False gap — bullet glyph + bare `{dep}` placeholder has no translatable content (the sibling `tooltipDepShared` carries the only translatable word, "(shared)"). The `fa.json` value was already correct (`• {dep}`); registered as a curated passthrough so the coverage gate stops flagging it. |

Both entries were added to `extension/scripts/i18n/dictionaries.py` (the durable source of truth that survives future regenerations) AND the Bengali value was hand-applied to `bn.json` so the fix ships in the catalog now without invoking the banned MT regen.

### 3. Deep review
- **Logic & safety:** Pure data edits — one JSON string value, two Python dict entries. No control flow.
- **Architecture/adherence:** The dictionary is the established override mechanism (`TRANSLATIONS[locale]` curated passthroughs, e.g. the existing `nl`/`bn`/`fa` blocks). Entries placed in alphabetical position within their locale block, each with a one-line WHY comment.
- **Why hand-edit `bn.json` (normally generated):** the i18n rule says not to hand-edit generated catalogs because a regen overwrites them — but regenerating requires running the MT pipeline, which is a hard standing prohibition and was not authorized for this run. Editing the dictionary alone would not reflect in the shipped catalog until the next regen; editing both keeps the catalog correct now and reproducible later. Documented in the dictionary comments.

### 4. Testing
- **Audit:** `report-html.test.ts:1035` pins `title="8,271,810 downloads in the last 30 days"` — the **English** (`en.json`) render with `{count}` interpolated. This change touches only `bn.json` (Bengali), not `en.json`, so the assertion is unaffected. No other test references the changed keys/strings.
- **Validation run:** `python -c "json.load(bn.json)"` → OK; `python -m py_compile dictionaries.py` → OK; loaded `TRANSLATIONS` and confirmed both entries resolve to the intended values; confirmed `bn.json packageDashboard.cells.downloadsCount` now reads the Bengali string (English placeholder gone).
- No new automated test added: the curated-dictionary mechanism is exercised by the existing `generate_translations.py` pipeline; a per-string unit test would pin MT-pipeline internals, not behavior.

### 5. Extension l10n validation
- `en.json` was **not** modified, so no full catalog regeneration is required for new source keys.
- Coverage gate: the two `bn`/`fa` gaps reported by the interrupted run's audit are now closed in the catalog + dictionary. The `--fail-on-missing` gate could not be re-run here because that requires invoking the MT pipeline (prohibited); effective missing count for these two strings is now zero by inspection.

### 6. Project maintenance
- CHANGELOG: added one Maintenance bullet under `[13.12.5]` describing the two-gap close (locale catalog only; no rule/runtime change).
- README verified — no updates needed (rule/fix counts unchanged).
- `pubspec` — no dependency/release change.
- ROADMAP — no lint entries affected.
- No bug archive — task did not close a `bugs/*.md` file.

### 7. Outstanding work — NOT part of this task (needs user authorization)
A systemic MT defect was found while doing this: the sentinel-shield placeholder token (`_PH0_` / `_ PH0__`) leaks into shipped output, with the engine appending garbage around it. **14 strings across the 5 just-processed locales (ar, bn, de, es, fa)** are affected, e.g. `bn tooltipDep` = `• {dep} _ PH0__ এর মাধ্যমে`, `ar tooltipDep` = `• {dep} _ PH0__ = الحالة المرضية.`, `es grade` = `Grado: {grade} El grado es de _PH0_.`. These pass the mechanical "differs from English = translated" check, so the coverage gate reports 100% while shipping broken copy. This is a sentinel-restoration bug in `generate_translations.py`, not a per-string gap — hand-fixing the 14 strings treats the symptom while the next MT run reintroduces them. Surfaced to the user with a y/n; they invoked `/finish` on the two-gap task instead of authorizing the root-cause fix, so it remains open and unaddressed.

### Files changed
- `extension/scripts/i18n/dictionaries.py` — `bn` + `fa` curated entries (4 lines incl. comments).
- `extension/src/i18n/locales/bn.json` — `downloadsCount` value (English → Bengali).
- `CHANGELOG.md` — one Maintenance bullet under `[13.12.5]`. (Note: the `[Unreleased]` → `[13.12.5]` header flip on this file pre-existed this task — separate release-prep edit.)
- `plans/history/2026.06/2026.06.10/i18n-manual-gap-fill-bn-fa.md` — this report.

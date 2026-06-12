# i18n Dashboard Tooltip MT-Garbage Cleanup

**Problem:** The i18n translation audit surfaced remaining missing-translation gaps to hand-fix. Fixing those surfaced a much larger problem: the package-dashboard tooltip/label keys carried hallucinated machine-translation output (trailing invented clauses, `_PH0_` artifacts, mistranslated technical terms) across nearly every locale. The manual cleanup extended first to four locales, then to all 24. NLLB / any MT pipeline was deliberately not run (hard prohibition); the read-only coverage gate was run in forced `--mode audit` to avoid the non-TTY `gaps` default that would touch the engine.

---

## Finish Report (2026-06-11)

### Scope

**(B)** VS Code extension i18n only — curated dictionary (`extension/scripts/i18n/dictionaries.py`) and the translated locale catalogs (`extension/src/i18n/locales/*.json`), plus a CHANGELOG entry. No Dart lint rules, analyzer plugin, or `en.json` source keys were touched. (`en.json` shows as modified in the tree from a separate Rule-Packs workstream — not this task.)

### What changed

Two phases against six package-dashboard keys: `downloadsCount`, `tooltipDep`, `tooltipDepShared`, `tooltipHeader`, `tooltipHeaderShared`, `sizeLabel`.

**Phase 1 — the genuinely-missing strings (stale-audit set):** `ur`/`zh` `downloadsCount` were shipping English → translated; `hi` `downloadsCount` (already translated in JSON by the prior commit) pinned in the dictionary so a regen can't revert it; `fil`/`sw` `{label}: {size}` and `vi` `• {dep}` are format-only strings (placeholders + a bullet/colon, no translatable words) → recorded as curated passthroughs.

**Phase 2 — garbled MT across all 24 locales:** the same MT garbage was present in nearly every locale. Applied via a deterministic one-shot script (`d:/tmp/`, deleted after) that replaced values **by JSON key** (these leaf keys are unique per file) to avoid transcribing garbled non-Latin source strings:

- `tooltipDep` → `• {dep}` everywhere — stripped hallucinations (`Pessoa com deficiência`, `фізіотерапія`, `מחזור הדם`, `การรักษาโรค`, `(Hücre)`, `_PH0_`, trailing `는`/`について`/`通过`).
- `tooltipHeader` / `tooltipHeaderShared` → correct per-language "transitive dependencies" rendering (`dependencias transitivas`, `推移的依存関係`, `전이 종속성`, `транзитивные зависимости`, `geçişli bağımlılıklar`, `תלויות טרנזיטיביות`, …), fixing mistranslations like Korean "geometric progression" and Russian "переходные отступы" (indents), and doubled `deps deps`.
- `sizeLabel` → `{label}: {size}` (identity); `fr` keeps its French colon spacing `{label} : {size}`.
- `downloadsCount` → cleaned word order / left-English fragments in `es`, `ja`, `ko`, `tr`, `sw`, `ur`, `zh`.

**Durability:** `dictionaries.py` now holds the two identity passthroughs — `• {dep}` in all 24 blocks and `{label}: {size}` in 23 (all except `fr`) — exactly once per block (two duplicate `{label}: {size}` entries introduced mid-task in `fil`/`sw` were removed), plus the four manual `downloadsCount`/`tooltipHeader` translations pinned for `ur`/`hi`/`zh`/`sw`. The identity passthroughs are required for the coverage gate: `compute_stats` counts a `"X": "X"` dict entry as translated, and these strings are not auto-skipped (`should_skip_machine_translate` returns False — residue after placeholder removal is empty, not a single letter).

### Verification

- **Coverage gate** (`generate_locales.py --mode audit --fail-on-missing`, read-only, no MT engine touched): all six task keys are out of the missing list in every locale. The 264 remaining "missing" are 11 new `{pack} rule pack` strings × 24 locales from a separate Rule-Packs workstream — out of scope for this task and a pre-existing publish-gate blocker, not a regression introduced here.
- **Placeholder integrity:** a script confirmed the placeholder set (`{count}`, `{dep}`, `{total}`, `{shared}`, `{label}`, `{size}`) for all six keys matches `en.json` exactly in all 24 locales.
- **Parse:** every locale JSON parses; `dictionaries.py` imports cleanly (24 locales, all values `str`).
- **Tests:** no existing test references the changed keys or values (the two TS matches for "transitive deps" are test *descriptions* about analyzer logic, not locale assertions). The python i18n suite could not execute — `pytest` is not installed in this environment — so it was audited by inspection only.

### Honest limitation (production-quality)

These are hand translations of short technical strings. They are verified for placeholder integrity, structural correctness, and JSON validity, but **not** reviewed by native speakers. The technical-term choices (e.g. Thai `การพึ่งพาทางอ้อม` "indirect dependencies", Vietnamese `phụ thuộc bắc cầu`) are reasonable but unverified by a human translator. The audit still lists them under "low-quality (upgrade candidates)" — that flag is a *provenance* heuristic meaning "not NLLB-sourced", which is true of all manual entries; it is not a correctness verdict. The prior state (hallucinated MT) was strictly worse.

### Files changed

- `extension/scripts/i18n/dictionaries.py` — passthroughs + manual translations across the 24 locale blocks; duplicate cleanup.
- `extension/src/i18n/locales/{ar,bn,de,es,fa,fr,he,hi,id,it,ja,ko,nl,pl,pt,ru,sw,th,tr,uk,ur,vi,zh}.json` — corrected tooltip/label values (23 of 24 catalogs; `fil` corrected too in phase 1).
- `CHANGELOG.md` — Fixed (Extension) bullet under [Unreleased].
- `plans/history/2026.06/2026.06.11/i18n_dashboard_tooltip_mt_cleanup.md` — this report.

### Out of scope / outstanding

- The 11 untranslated `{pack} rule pack` strings (Rule-Packs workstream) keep the publish coverage gate red; not addressed here.
- `No bug archive — task did not close a bugs/*.md file.`
- ROADMAP: SKIPPED — not a lint-rule change. README verified — no rule/doc counts changed. guides reviewed.

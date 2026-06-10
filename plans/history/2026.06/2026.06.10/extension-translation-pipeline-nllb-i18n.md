# Extension Translation Pipeline — NLLB engine, full i18n coverage, operator controls

**Trigger:** The user asked to translate the saropa_lints VS Code extension with NLLB-200-3.3B quality (the engine they'd seen in the contacts project), then — over the same session — to fully internationalize the webview dashboards, harden the pipeline's robustness, and add operator controls (graceful cancel, gaps-vs-upgrade modes, provenance, key editing) for the long translation runs.

## Finish Report (2026-06-10)



### Scope
(B) VS Code extension — TypeScript webviews + i18n runtime catalog + Python i18n build scripts. (C) docs — CHANGELOG, a new active plan, a gitignored project rule. NOT (A) Dart lint rules.

### What shipped (one cohesive feature: the extension translation pipeline)

1. **NLLB-200-3.3B engine** (`extension/scripts/i18n/nllb_engine.py`, new) — a self-contained CTranslate2 engine lifted faithfully from the contacts pipeline: FLORES-200 language map (~90 langs), model-dir resolution (shares the contacts default + env vars → no second download), pip bootstrap, CUDA/cuBLAS auto-setup, device cascade (CUDA fp16 → CPU int8 → CPU fp16) with a load-probe, 80-token input gate, sentence-split routing, per-call wall-clock timeout, greedy decode with repetition penalties. Dropped the contacts ARB-runner coupling (orphan-drain, cross-locale circuit breakers) the extension doesn't need. `--setup`, `--probe`, status CLIs.
   - **Fix during the session:** `_add_packages_to_path` now APPENDS the `--target` packages dir instead of prepending, so a broken/AV-locked `typing_extensions.py` in that dir can't shadow and poison system imports (it had crashed both NLLB load and the Google fallback under Python 3.14). `_is_model_cached` switched from `snapshot_download(local_files_only)` to a direct filesystem check (the hub API gave false negatives). `status_summary()` distinguishes disabled / not-downloaded / runtime-built-for-another-Python.

2. **Engine wiring** (`mt_fallback.py`) — NLLB is the primary engine, Google the per-string fallback, with engine-namespaced cache keys so a Google-only cache upgrades to NLLB transparently. NLLB gets its OWN `__PH__` placeholder mask (the contacts-proven scheme) instead of the Google `ZZ0ZZ` shield, and `_nllb_fetch` rejects any result where a placeholder/brand marker didn't survive verbatim → falls back to Google rather than ship corruption.

3. **Full webview i18n** — 265 previously-hardcoded English strings across `report-html.ts` (64), `package-detail-html.ts` (100), `comparison-html.ts` (52), `detail-view-html.ts` (43), `chart-html.ts` (6) extracted to `l10n('…')` calls (parallel per-file editors), and 189 new keys merged into `en.json` (deep-merge, collision-checked). Three of the five views had ZERO i18n before.

4. **Provenance + visibility** — persistent per-string engine provenance sidecar (`.cache/mt_provenance.json`: nllb/google/english/manual), and a per-locale run report (`engines -> nllb:X, google:Y, english:Z`) so a silent NLLB→Google fallback is visible instead of hidden behind the "NLLB ready" banner.

5. **Operator controls for long runs** —
   - Graceful cooperative **Ctrl-C**: first press finishes the in-flight string, flushes cache + provenance, exits 130 (resumable); second force-quits. Checkpoint every 25 strings. `generate_translations.py` ignores SIGINT so it can't tear the child down mid-save.
   - **`--mode`** gaps / upgrade (re-translate Google/English → NLLB) / all (force, keeps manual), via pre-run cache pruning + interactive menu.
   - **`--show` / `--set` / `--unset`** to inspect, manually override (provenance 'manual', never re-translated), or remove cached translations.

### Tests
52 passing: `test_nllb_engine` (10), `test_nllb_wiring` (18, +7), `test_mt_fallback` (16, audited unbroken), `test_mt_provenance_modes` (8, new — provenance recording, prune-for-mode, key set/unset, stop flag). Existing tests referencing `_fetch_translation`/`_translate_one`/`machine_translate` audited — none broke. `tsc --noEmit` exit 0. 351 static `l10n` keys resolve, 0 missing.

### Verification boundary (honest)
The end-to-end NLLB run and the actual translation quality are UNVERIFIED by the assistant — running the model / the MT pipeline is under a standing prohibition. All logic is unit-tested up to the model-load and fetch boundaries (stubbed). Two operator actions remain:
1. **Regenerate catalogs** (REQUIRED before publish): `py -3 extension/scripts/generate_translations.py`. `en.json` has 189 new keys; the 24 locale catalogs are stale until this runs, so non-English renders English for the new strings.
2. **`nllb_engine.py --probe`** to confirm the `__PH__` mask survives NLLB across scripts (ar/hi/zh/ru/de/fr).

### Out of scope / follow-ups
- `plans/ADD_15_PROGRAMMER_LOCALES.md` (new active plan) — wiring 15 more languages (25 → 40); not started.
- The contacts-side review fixes (dead vars + process-guard substring) live uncommitted in `D:\src\contacts` (different repo) — not part of this commit.

### Files committed (this task)
`extension/scripts/i18n/nllb_engine.py`, `extension/scripts/i18n/mt_fallback.py`, `extension/scripts/i18n/generate_locales.py`, `extension/scripts/generate_translations.py`, `extension/scripts/i18n/tests/test_nllb_wiring.py`, `extension/scripts/i18n/tests/test_mt_provenance_modes.py`, `extension/src/i18n/locales/en.json`, `extension/src/vibrancy/views/{report,package-detail,comparison,detail-view,chart}-html.ts`, `plans/ADD_15_PROGRAMMER_LOCALES.md`, this report. (CHANGELOG entries already committed in a prior workstream commit. `.claude/rules/i18n.md` is gitignored — local only. Global CLAUDE.md / finish skill / memory updates live outside the repo.)

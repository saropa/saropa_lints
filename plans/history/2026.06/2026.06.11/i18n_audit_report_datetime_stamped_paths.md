# i18n Audit Report — Datetime-Stamped Output Paths

The user reported that audit output logs must be datetime-stamped rather than written to a single fixed file. The triggering observation: an audit-only run of `generate_translations.py` wrote its report to the fixed path `extension/reports/i18n_translation_audit.md`, overwriting any prior run. Required convention (verbatim from the user): `reports/<date>/<date_time>_<name>` — e.g. `reports/20260611/20260611_005206_i18n_translation_audit.md`.

## Finish Report (2026-06-11)



### Scope

(C) docs/scripts only. The change is confined to the extension i18n build tooling (`extension/scripts/i18n/`), a developer/CI script that is excluded from the published `.vsix` and the pub.dev package. No Dart lint rules, analyzer plugin, tiers, or runtime behavior touched.

### Change summary

- **`extension/scripts/i18n/generate_locales.py`**
  - Added `timestamped_report_path(root, filename)` — a pure-ish helper that returns `root/reports/<YYYYMMDD>/<YYYYMMDD_HHMMSS>_<filename>` and creates the dated directory (`mkdir(parents=True, exist_ok=True)`) so the caller can open the file immediately. Uses local wall-clock `datetime.now()` so the stamp reads as the operator's run time (the in-report `Generated:` line keeps its existing UTC timestamp — unchanged).
  - Audit-only mode (`run_audit`): the audit report path now comes from `timestamped_report_path(root, "i18n_translation_audit.md")` instead of the fixed `root / "reports" / "i18n_translation_audit.md"`.
  - Translate mode: the same audit-report path is now stamped identically.
  - The NLLB fallback report (`i18n_nllb_fallbacks.md`, translate mode only) routes through the same helper for consistency — it is the same class of "output log" written to `reports/`.
- **`extension/scripts/i18n/tests/test_report_path.py`** (new) — two tests pinning the path contract: exact day-bucket + second-stamp layout (with `datetime.now` stubbed for determinism) and basename preservation for the fallback report. Confirms the dated parent directory is created.
- **`CHANGELOG.md`** — new `<details><summary>Maintenance</summary>` block under `[Unreleased]` (build-tooling-only entry; no user-facing impact).

### Deep review notes

- **Logic & safety:** `mkdir(exist_ok=True)` is idempotent; concurrent runs in the same second would target the same file, but audit runs are operator-invoked and serial — not a real race. No recursion, no unbounded growth introduced (day-bucketing means stamped files accumulate; pruning is out of scope and was not requested).
- **No fixed-path consumer broke:** grepped the whole repo for `i18n_translation_audit` / `i18n_nllb_fallbacks` — only `generate_locales.py` referenced them. The publish coverage gate (`generate_locales.py --fail-on-missing`) keys off the in-memory `total_missing` count and a non-zero exit code, not the report file path, so stamping does not affect CI gating.
- **Single source of truth:** path layout now lives in one helper rather than being repeated as a literal at three call sites.

### Testing

- New: `python extension/scripts/i18n/tests/test_report_path.py` → 2 tests, OK.
- Existing (model-free) suites re-run to confirm no regression from the added function: `test_phrase_split` (17), `test_progress` (6), `test_nllb_wiring` (18) → all OK.
- Audited the test directory by grep for the changed symbols (`i18n_translation_audit`, `timestamped_report_path`, `write_audit_report`, `write_fallback_report`, `report_path`, `reports`, `i18n_nllb_fallbacks`): no existing test pinned these paths, so none needed updating.
- `python -c "import ast; ast.parse(...)"` and a live `import generate_locales` both succeed (module-load is guarded by `if __name__ == "__main__"`; no model loads on import).

### Out of scope / not done

- I did not run any translation pipeline (NLLB / Google / `setup_arb_translate.py`). The pasted terminal log included a `setup_arb_translate.py` invocation in the `d:\src\contacts` project — a different repo and a translation job — which I neither ran nor edited.
- No pruning/retention policy for accumulated stamped reports was added (not requested).

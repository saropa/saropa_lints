# CHANGELOG 6.2.0 review — committed and uncommitted vs documented

**Scope:** Current working pre-release version **6.2.0**. Compare repo state (committed + uncommitted) with what is listed under `## [6.2.0]` in CHANGELOG.md.

---

## 1. Missing from 6.2.0 (should add)

### 1.1 `require_database_close` fix (**Fixed**)

- **What:** Rule no longer reports when the method body only references `openDatabase` (or similar) in **string literals** or **name checks** (e.g. rule code that does `methodName != 'openDatabase'`). Only **invocations** like `openDatabase(`, `Database(`, `SqliteDatabase(` are treated as “opens DB.” The rule also **skips** its own rule files (`file_handling_rules.dart`, `sqflite_rules.dart`) to avoid self-report.
- **Where:** Implemented in `lib/src/rules/resources/resource_management_rules.dart` (committed in refactor 25140909 — rules layout).
- **Doc:** `bugs/history/false_positives/require_database_close_false_positive_string_literal_rule_files.md`.
- **Action:** Add a bullet under **### Fixed** in 6.2.0.

### 1.2 Self-check package (**Added**)

- **What:** Optional package `self_check/` (name: `saropa_lints_self_check`) to run saropa_lints on the package itself. README recommends validating from repo root with `dart analyze` (full rule set); optional `dart analyze self_check` analyzes only the small stub in `self_check`.
- **Where:** Untracked: `self_check/` (pubspec.yaml, lib/, analysis_options.yaml, README.md, pubspec.lock).
- **Action:** Add a short bullet under **### Added** (e.g. optional self-check package for validating saropa_lints itself).

### 1.3 Script `scripts/analyze_to_log.ps1` (**Added** — optional)

- **What:** PowerShell script to run `dart analyze` and write all output to a timestamped log under `reports/`.
- **Where:** Untracked: `scripts/analyze_to_log.ps1`.
- **Action:** Optional: add under **### Added** or **### Maintenance** (e.g. “Script to run dart analyze and log output to reports/”).

---

## 2. Uncommitted changes summary

| Category | Examples | In 6.2.0? |
|----------|----------|------------|
| **CHANGELOG.md** | Tidy of 6.2.0 sections (grouped Fixed/Changed) | N/A (the doc itself) |
| **History/roadmap cleanup** | Many **deleted**: `bugs/BATCH_3_4_REVIEW.md`, `bugs/history/*.md`, `bugs/not_viable_drift_rules.md`, `bugs/roadmap/open_issues/task_*.md` (67 files) | Partially — “History integration”, “removed … files” cover intent; not every deletion is itemized |
| **New history files** | `bugs/history/false_positives/require_database_close_...`, `false_positive_avoid_unawaited_future_...`, `bugs/history/issues/BUG_REPORT_copyWith_...`, `duplicate_rules_...` | copyWith and duplicate_rules are in **Fixed**; require_database_close and unawaited_future are documented in their bugs/ docs but require_database_close not in CHANGELOG |
| **Lib/bin/config** | Modifications to `analysis_options.yaml`, `bin/*.dart`, `lib/main.dart`, `lib/saropa_lints.dart`, many `lib/src/*` (baseline, report, rules, fixes, etc.), `scripts/modules/_publish_steps.py`, `test/roadmap_detail_rules_test.dart`, `cspell.json`, `example_core/.../avoid_high_cyclomatic_complexity_fixture.dart` | Most are covered by existing 6.2.0 bullets (defensive coding, rules layout, quick fixes, init wizard, etc.). Optional: mention analysis_options or self_check exclude if user-facing. |
| **New / moved** | `self_check/`, `scripts/analyze_to_log.ps1` | Not in 6.2.0 — see §1.2, §1.3 |

---

## 3. Committed work vs 6.2.0

Recent commits (after Release v6.1.2) are well reflected in 6.2.0:

- Fixes: prefer_platform_io_conditional, avoid_redirect_injection, require_deep_link_fallback, avoid_unawaited_future, avoid_uncaught_future_errors, copyWith (complexity + long param list), duplicate rules (prefer_named_bool_params).
- Init wizard (ruleset-based), ignore handling (no_empty_block), rules layout (subfolders), quick fixes (Batches 6–9), new rules (batch 3–4 / roadmap), defensive coding, history integration, documentation batches.

**Gap:** The **require_database_close** fix was committed as part of the rules-layout refactor (25140909) but is **not** called out in 6.2.0.

---

## 4. Recommended CHANGELOG edits for 6.2.0

1. **### Fixed** — Add:
   - **`require_database_close`:** No longer reports when the method body only references `openDatabase` (or similar) in string literals or name checks; only actual invocations (`openDatabase(`, `Database(`, `SqliteDatabase(`) are treated as opening a DB. Skips own rule files (`file_handling_rules.dart`, `sqflite_rules.dart`). See `bugs/history/false_positives/require_database_close_false_positive_string_literal_rule_files.md`.

2. **### Added** — Add (optional):
   - **Self-check package:** Optional package `self_check/` to run saropa_lints on the package itself; README recommends `dart analyze` from repo root for full validation.
   - **Script:** `scripts/analyze_to_log.ps1` to run dart analyze and write output to a timestamped log in `reports/`.

3. No change needed for the large history/roadmap file deletions if you’re satisfied with the existing “History integration” and “removed … files” wording; otherwise add a brief **### Maintenance** or **### Documentation** note that roadmap open_issues and integrated history files were removed.

---

## 5. Summary

| Item | In repo (committed/unchanged) | In 6.2.0 CHANGELOG |
|------|-------------------------------|--------------------|
| require_database_close fix | Yes (in rules refactor commit) | **No** → add under Fixed |
| Self-check package | Yes (untracked) | **No** → add under Added (optional) |
| analyze_to_log.ps1 | Yes (untracked) | **No** → add under Added (optional) |
| History/roadmap deletions | Uncommitted | Covered at high level |
| copyWith / duplicate_rules | Yes | Yes |
| Other 6.2.0 items | Yes | Yes |

**Bottom line:** The only **clear omission** is the **require_database_close** fix. Self-check and the script are **optional** changelog entries. The rest of the committed and uncommitted work is either already described in 6.2.0 or is internal/maintenance.

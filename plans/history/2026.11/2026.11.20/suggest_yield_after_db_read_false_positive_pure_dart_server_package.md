# BUG: `suggest_yield_after_db_read` — also `require_yield_after_db_write`: file I/O in a pure-Dart server flagged with a Flutter `yieldToUI()` suggestion

**Status: Fixed (duplicate) — Flutter gate already shipped; see plans/history/2026.09/2026.09.18/*_one_shot_file_io_non_flutter_server.md**

Created: 2026-11-20
Rule: `suggest_yield_after_db_read`
File: `lib/src/rules/resources/db_yield_rules.dart` (line ~449)
Severity: False positive (3 hits (2 read + 1 write))
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Both rules fire on `File.readAsString`/write calls in a pure-Dart debug server (`generation_handler.dart:695`, `snapshot_store.dart:44`, `snapshot_store.dart:85`). The suggested remedy (`yieldToUI()`) is a Flutter concept; the package has no UI isolate, and the calls are file I/O, not database access.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'suggest_yield_after_db_read'" lib/src/rules/
# lib/src/rules/resources/db_yield_rules.dart:449

# Negative — rule is NOT in the drift advisor repo
grep -rn "'suggest_yield_after_db_read'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/resources/db_yield_rules.dart:449`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `suggest_yield_after_db_read`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
import 'dart:io';

Future<String> load(File f) async {
  final text = await f.readAsString(); // LINT (suggest_yield_after_db_read) — should NOT lint
  return text;
}

Future<void> save(File f, String s) async {
  await f.writeAsString(s); // LINT (require_yield_after_db_write) — should NOT lint
}
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[suggest_yield_after_db_read]` reported — `suggest_yield_after_db_read` / `require_yield_after_db_write` on file I/O |

---

## Root Cause

Per review: both rules match by call-name pattern with no check that the project depends on Flutter, and they treat `File` I/O as database access. Registration: `lib/src/rules/resources/db_yield_rules.dart:449` (`suggest_yield_after_db_read`) and `:376` (`require_yield_after_db_write`).

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

Skip both rules when the project has no Flutter dependency, and restrict the matched receivers to database types (drift/sqflite/etc.) rather than `dart:io` `File`.

---

## Fixture Gap

Fixture additions: `File.readAsString` in a non-Flutter project — expect NO lint; drift query followed by heavy loop in a Flutter project — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/generation_handler.dart:695`, `lib/src/server/snapshot_store.dart:44,85`

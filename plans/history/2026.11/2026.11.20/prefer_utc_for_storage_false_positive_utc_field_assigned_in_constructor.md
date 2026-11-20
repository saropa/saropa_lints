# BUG: `prefer_utc_for_storage` — false positive when a field holding an already-UTC value is read at the storage site

**Status: Fixed**

Created: 2026-11-20
Rule: `prefer_utc_for_storage`
File: `lib/src/rules/core/async_rules.dart` (line ~2069)
Severity: False positive (4 hits)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

The rule flags `at`/`createdAt` values written to storage even though each is built with `.toUtc()` upstream (constructor argument or field initializer). The rule checks the receiver expression structurally and cannot see through a field read. NOTE: `plans/history/2026.09/2026.09.18/prefer_utc_for_storage_false_positive_already_utc_via_upstream_construction.md` covers a related case; the reporter's plugin build may predate it. Confirm on a current build whether this field-read shape is already handled before fixing.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_utc_for_storage'" lib/src/rules/
# lib/src/rules/core/async_rules.dart:2069

# Negative — rule is NOT in the drift advisor repo
grep -rn "'prefer_utc_for_storage'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/async_rules.dart:2069`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `prefer_utc_for_storage`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
class Entry {
  Entry(DateTime now) : at = now.toUtc();
  final DateTime at;
}

Map<String, Object?> toJson(Entry e) => {
  'at': e.at.toIso8601String(), // LINT — should NOT lint (field is UTC by construction)
};
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[prefer_utc_for_storage]` reported — storage of a possibly-local DateTime at `host_statement_capture.dart:220`, `snapshot_handler.dart:52`, `table_activity_tracker.dart:192`, `server_context.dart:761` |

---

## Root Cause

Per review: the rule inspects the expression at the storage call. A field/property read has no `.toUtc()` in its source, so it is reported. It does not trace the field to its constructor-initializer or assignment sites.

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

When the operand is a field read, resolve the field and skip if every initializer/assignment in the class is a `.toUtc()` call or a `DateTime.utc(...)` expression.

---

## Fixture Gap

Fixture additions: field assigned only via `.toUtc()` in the constructor, read at the storage site — expect NO lint; field assigned from `DateTime.now()` — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/host_statement_capture.dart:220`, `snapshot_handler.dart:52`, `table_activity_tracker.dart:192`, `server_context.dart:761`

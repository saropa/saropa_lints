# BUG: `require_isolate_for_heavy` — false positive on `jsonEncode` of small literal maps in a pure-Dart server

**Status: Open**

Created: 2026-11-20
Rule: `require_isolate_for_heavy`
File: `lib/src/rules/core/performance_rules.dart` (line ~5062)
Severity: False positive (11 hits in one file)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

The rule flags `jsonEncode(<String, String>{ 'error': '...' })` in async request handlers as heavy work that should run in an isolate. The payload is a tiny literal map, and the package is a pure-Dart `dart:io` server with no UI isolate, yet the message talks about blocking the UI event loop.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_isolate_for_heavy'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:5062

# Negative — rule is NOT in the drift advisor repo
grep -rn "'require_isolate_for_heavy'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:5062`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `require_isolate_for_heavy`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
import 'dart:convert';
import 'dart:io';

Future<void> sendError(HttpResponse res, String message) async {
  res.write(jsonEncode(<String, String>{'error': message})); // LINT — should NOT lint
  await res.close();
}
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[require_isolate_for_heavy]` reported — heavy operation `jsonEncode` in async context (11 hits in `router.dart`) |

---

## Root Cause

Per review: `_heavyOperations` is matched by name only (`jsonEncode`, `jsonDecode`, `parse`, `hash`, ...) combined with `isInAsyncContext`. There is no payload-size heuristic and no check that the project depends on Flutter (a UI isolate exists only there).

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

(1) Skip the rule when the project has no Flutter dependency. (2) Skip `jsonEncode`/`jsonDecode` when the argument is a map/list literal (statically bounded size).

---

## Fixture Gap

Fixture additions: `jsonEncode` of a literal map in async handler — expect NO lint; `jsonDecode(await file.readAsString())` — expect LINT; non-Flutter project — expect NO lint.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/router.dart` (error and toggle responses)

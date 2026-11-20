# BUG: `avoid_case_sensitive_path_comparison` — root-detection idiom still flagged when the directory variable is reassigned in the loop; also HTTP `uri.path` in compare_handler

**Status: Open**

Created: 2026-11-20
Rule: `avoid_case_sensitive_path_comparison`
File: `lib/src/rules/platforms/windows_rules.dart` (line ~417)
Severity: False positive (5 hits across 2 classes)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Two patterns still fire. (A) `parent.path == dir.path` in an upward directory walk — the rule claims to exempt the root-detection idiom (`_isRootDetectionIdiom`, ~line 513) but still reports it when `dir` is reassigned in the loop. (B) `req.uri.path` compared with route constants in an HTTP handler (same class as `avoid_case_sensitive_path_comparison_false_positive_http_route_constant.md`).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_case_sensitive_path_comparison'" lib/src/rules/
# lib/src/rules/platforms/windows_rules.dart:417

# Negative — rule is NOT in the drift advisor repo
grep -rn "'avoid_case_sensitive_path_comparison'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/platforms/windows_rules.dart:417`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `avoid_case_sensitive_path_comparison`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
import 'dart:io';

Directory? findRoot(Directory start) {
  var dir = start;
  while (true) {
    final parent = dir.parent;
    if (parent.path == dir.path) break; // LINT — should NOT lint (root detection)
    dir = parent;
  }
  return dir;
}

// Class B — HTTP route path, case-sensitive by RFC 3986
bool isReport(HttpRequest req) => req.uri.path == '/api/compare/report'; // LINT — should NOT lint
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_case_sensitive_path_comparison]` reported — case-sensitive path comparison at `generation_handler.dart:737/764/797` (A) and `compare_handler.dart:45-46` (B) |

---

## Root Cause

Per review: for (A), the idiom check includes a reassignment guard that rejects the pattern because `dir = parent` assigns the compared variable inside the loop — but that reassignment is exactly what defines the idiom. For (B), see the existing HTTP-route bug; `_isUriPathAccess` does not trace through the local `final path = req.uri.path;` in these files.

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

(A) Drop or relax the reassignment guard for the `x.parent.path == x.path` shape. (B) Resolve local declarations initialized from `HttpRequest.uri.path` before deciding the operand is a filesystem path.

---

## Fixture Gap

Fixture additions: upward walk with `dir = parent` reassignment — expect NO lint; `final path = req.uri.path; if (path == X)` — expect NO lint; `File(a).path == File(b).path` — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/generation_handler.dart:737,764,797`, `lib/src/server/compare_handler.dart:45-46`

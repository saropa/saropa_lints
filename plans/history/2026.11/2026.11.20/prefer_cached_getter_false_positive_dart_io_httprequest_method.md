# BUG: `prefer_cached_getter` — false positive on repeated `HttpRequest.method` reads

**Status: Open**

Created: 2026-11-20
Rule: `prefer_cached_getter`
File: `lib/src/rules/core/performance_rules.dart` (line ~679)
Severity: False positive (13 hits in one file)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

The rule flags repeated reads of `request.method` (a `dart:io` `HttpRequest` getter that returns a stored field) as an expensive getter that should be cached. Reading a trivial SDK accessor several times in an `if` chain costs nothing and caching adds noise.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_cached_getter'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:679

# Negative — rule is NOT in the drift advisor repo
grep -rn "'prefer_cached_getter'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:679`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `prefer_cached_getter`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
import 'dart:io';

Future<void> dispatch(HttpRequest request, String path) async {
  if (request.method == 'GET' && path == '/a') {} // LINT — should NOT lint
  if (request.method == 'GET' && path == '/b') {} // LINT — should NOT lint
  if (request.method == 'POST' && path == '/c') {} // LINT — should NOT lint
}
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[prefer_cached_getter]` reported — repeated getter access `request.method` (13 occurrences in `lib/src/server/router.dart`) |

---

## Root Cause

Per review of the rule: `_isKnownCheapGetter` allowlists only `length`/`isEmpty`/`isNotEmpty`/`first`/`last` on List/String/Set/Map plus unoverridden `hashCode`. Any other declared SDK getter, including `HttpRequest.method`, is treated as potentially expensive.

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

Broaden the cheap-getter allowlist to getters declared in `dart:` SDK libraries that are plain field reads (at minimum `HttpRequest.method`, `HttpRequest.uri`, `HttpRequest.headers`, `Uri.path`, `Uri.query`), or only fire when the getter body is user-defined (declared in the analyzed package) rather than SDK-declared.

---

## Fixture Gap

Add to the rule fixture: repeated `HttpRequest.method` reads — expect NO lint; repeated user-defined getter with a computed body — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/router.dart` (route dispatch chains)

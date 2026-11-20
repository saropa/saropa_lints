# BUG: `require_data_encryption` — false positive on `HttpResponse.write` (network response, not storage)

**Status: Fixed**

Created: 2026-11-20
Rule: `require_data_encryption`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (line ~1370)
Severity: False positive (4 hits)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

The rule treats `res.write(jsonEncode(...))` on a `dart:io` `HttpResponse` as unencrypted data storage. Writing to a response is network output, not persistence.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_data_encryption'" lib/src/rules/
# lib/src/rules/security/security_auth_storage_rules.dart:1370

# Negative — rule is NOT in the drift advisor repo
grep -rn "'require_data_encryption'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/security/security_auth_storage_rules.dart:1370`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `require_data_encryption`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
import 'dart:convert';
import 'dart:io';

Future<void> reply(HttpResponse res, Map<String, Object?> body) async {
  res.write(jsonEncode(body)); // LINT — should NOT lint (HTTP response)
  await res.close();
}
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[require_data_encryption]` reported — unencrypted write at `auth_handler.dart:107`, `generation_handler.dart:138/153/210` |

---

## Root Cause

Per review: the rule matches the method name `write` and exempts only `StringBuffer`/`StringSink` receivers (`security_auth_storage_rules.dart` ~1568-1590). `HttpResponse` is not exempted. This is distinct from the 2026.09.18 fix for auth-status metadata keywords.

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

Resolve the receiver's static type and skip `HttpResponse`, `IOSink`, `Socket`, `WebSocket` and other network/stream sinks; only flag `File.writeAsString`/`writeAsBytes`/`RandomAccessFile.write` style persistence.

---

## Fixture Gap

Fixture additions: `HttpResponse.write(jsonEncode(...))` — expect NO lint; `File.writeAsString(token)` — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/auth_handler.dart:107`, `lib/src/server/generation_handler.dart`

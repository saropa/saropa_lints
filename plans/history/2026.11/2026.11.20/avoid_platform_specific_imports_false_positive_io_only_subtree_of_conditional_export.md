# BUG: `avoid_platform_specific_imports` — false positive on files only reachable through an `if (dart.library.io)` conditional export

**Status: Open**

Created: 2026-11-20
Rule: `avoid_platform_specific_imports`
File: `lib/src/rules/config/config_rules.dart` (line ~707)
Severity: False positive (22 hits)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Every file in the io-only implementation subtree is flagged for importing `dart:io`, although the package's public entry point reaches that subtree only through `export 'stub.dart' if (dart.library.io) 'io.dart';`. Web builds never compile those files.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_platform_specific_imports'" lib/src/rules/
# lib/src/rules/config/config_rules.dart:707

# Negative — rule is NOT in the drift advisor repo
grep -rn "'avoid_platform_specific_imports'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/config/config_rules.dart:707`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `avoid_platform_specific_imports`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
// lib/src/drift_debug_server.dart
export 'drift_debug_server_stub.dart'
    if (dart.library.io) 'drift_debug_server_io.dart';

// lib/src/server/auth_handler.dart — only imported (transitively) by drift_debug_server_io.dart
import 'dart:io'; // LINT — should NOT lint
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_platform_specific_imports]` reported — platform-specific import `dart:io` in 22 files under `lib/src/server/` |

---

## Root Cause

Per review: the rule skips only when the import directive itself carries `configurations`, the package is a CLI/analyzer plugin, or the path contains a platform directory. `conditional_import_utils.dart` (`_nativeOnlyTargetsByProject`) already computes the io-only target set but it contains only the io target file itself, not files that file imports, and this rule does not consult it.

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

Extend the native-only set to the transitive import closure of each conditional-export io target, and have this rule skip files in that closure. Web-reachable files that import `dart:io` unconditionally must still be flagged.

---

## Fixture Gap

Fixture additions: file imported only from the `dart.library.io` target of a conditional export, importing `dart:io` — expect NO lint; file reachable from the stub/web path importing `dart:io` — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/*.dart` (conditional export at `lib/src/drift_debug_server.dart:8`)

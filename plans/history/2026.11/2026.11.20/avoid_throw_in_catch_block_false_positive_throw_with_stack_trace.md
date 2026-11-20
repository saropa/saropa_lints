# BUG: `avoid_throw_in_catch_block` — false positive on `Error.throwWithStackTrace`, which preserves the original stack

**Status: Open**

Created: 2026-11-20
Rule: `avoid_throw_in_catch_block`
File: `lib/src/rules/flow/exception_rules.dart` (line ~216)
Severity: False positive (1 hit)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

The rule flags a throw inside a catch block because it loses the original stack trace. `Error.throwWithStackTrace(wrapped, originalStack)` explicitly carries the original stack, so the rule's stated concern does not apply.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_throw_in_catch_block'" lib/src/rules/
# lib/src/rules/flow/exception_rules.dart:216

# Negative — rule is NOT in the drift advisor repo
grep -rn "'avoid_throw_in_catch_block'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/flow/exception_rules.dart:216`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `avoid_throw_in_catch_block`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
Future<void> run(Future<void> Function() op) async {
  try {
    await op();
  } on Object catch (e, stack) {
    // Wraps the error but keeps the original stack trace.
    Error.throwWithStackTrace(StateError('wrapped: $e'), stack); // LINT — should NOT lint
  }
}
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_throw_in_catch_block]` reported — throw in catch block at `lib/src/server/edits_batch_handler.dart:80` |

---

## Root Cause

Per review: the rule matches throw-like nodes within a `CatchClause` body and does not recognize `Error.throwWithStackTrace` as stack-preserving. The downstream code uses it as the operand of `throw` to satisfy a `Never` return type.

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

Exempt `Error.throwWithStackTrace(_, stackArg)` where `stackArg` is the catch clause's stack-trace parameter.

---

## Fixture Gap

Fixture additions: `Error.throwWithStackTrace(x, stack)` with the catch's own stack variable — expect NO lint; `throw Wrapped(e)` without stack — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/edits_batch_handler.dart:80`

# BUG: `avoid_unnecessary_nullable_fields` — false positive when the constructor initializer is a conditional that can yield null

**Status: Open**

Created: 2026-11-20
Rule: `avoid_unnecessary_nullable_fields`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~2068)
Severity: False positive (1 hit)
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

The rule reports a nullable field as unnecessarily nullable even though its only initializer is `cond ? Value(...) : null`, so the field is genuinely null in some instances.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_unnecessary_nullable_fields'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:2068

# Negative — rule is NOT in the drift advisor repo
grep -rn "'avoid_unnecessary_nullable_fields'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:2068`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (rule code `avoid_unnecessary_nullable_fields`) in `bugs/lints.json` of the downstream project.

---

## Reproducer

```dart
class Router {
  Router({int? maxRequestsPerSecond})
    : _rateLimiter = maxRequestsPerSecond != null
          ? RateLimiter(maxRequestsPerSecond)
          : null;

  final RateLimiter? _rateLimiter; // LINT — should NOT lint (null when maxRequestsPerSecond is null)
}
```

**Frequency:** Always on the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_unnecessary_nullable_fields]` reported — field `_rateLimiter` can be non-nullable (`lib/src/server/router.dart:81`) |

---

## Root Cause

Per review: the rule treats an initializer as null only when `init.expression is NullLiteral`. Ternaries, `??` chains and any expression whose static type is nullable are counted as non-null initializers.

Mechanism was derived by reading the rule source and the flagged code; it was NOT reproduced under a debugger or via `dart test`.

---

## Suggested Fix

Treat an initializer as possibly-null when it is a `ConditionalExpression` with a null-literal branch, or any expression whose `staticType` is nullable. Only report when every constructor initializer is provably non-null.

---

## Fixture Gap

Fixture additions: ternary-with-null initializer — expect NO lint; `??` with nullable right side — expect NO lint; non-null literal in every constructor — expect LINT.

---

## Environment

- saropa_lints version: unknown — findings come from the VS Code diagnostics export `saropa_drift_advisor/bugs/lints.json` (plugin build not recorded; may predate fixes under `plans/history/2026.09/2026.09.18/`). Re-scan on current build before fixing.
- Dart SDK version: 3.9+ (package floor)
- custom_lint version: n/a (IDE diagnostics export)
- Triggering project/file: `D:\src\saropa_drift_advisor` — `lib/src/server/router.dart:81`

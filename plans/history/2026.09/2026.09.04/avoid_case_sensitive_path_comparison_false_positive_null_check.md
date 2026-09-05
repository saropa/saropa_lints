# BUG: `avoid_case_sensitive_path_comparison` — false positive on null/emptiness checks

**Status: Fixed**

Created: 2026-09-04
Rule: `avoid_case_sensitive_path_comparison`
File: `lib/src/rules/platforms/windows_rules.dart` (line ~316)
Severity: False positive
Rule version: v3 | Since: v4.9.20 | Updated: v4.13.0

---

## Summary

The rule fires on `== null` and `!= null` comparisons when the variable name contains a path-like substring (e.g. `filePathUrl`). Null/emptiness checks are not case-sensitive comparisons and should not be flagged.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_case_sensitive_path_comparison'" lib/src/rules/
# lib/src/rules/platforms/windows_rules.dart:302: 'avoid_case_sensitive_path_comparison',

# Negative — rule is NOT in sibling repos
grep -rn "'avoid_case_sensitive_path_comparison'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/platforms/windows_rules.dart:302`
**Rule class:** `AvoidCaseSensitivePathComparisonRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
class Example {
  void method(String? filePathUrl) {
    if (filePathUrl == null || filePathUrl.isEmpty) {  // LINT — but should NOT lint
      return;
    }
    // Use filePathUrl...
  }
}
```

**Frequency:** Always — any `== null` / `!= null` / `.isEmpty` guard on a variable whose name contains "path", "file", "dir", etc.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `== null` is a nullability guard, not a case-sensitive string comparison |
| **Actual** | `[avoid_case_sensitive_path_comparison] File path compared without case normalization. Windows filesystem is case-insensitive.` reported on the `==` / `!=` operator |

---

## AST Context

```
MethodDeclaration (method)
  └─ Block
      └─ IfStatement
          └─ BinaryExpression (||)
              └─ BinaryExpression (==)          ← node reported here
                  ├─ SimpleIdentifier (filePathUrl)
                  └─ NullLiteral (null)
```

---

## Root Cause

### Hypothesis A: No null-literal exclusion

`runWithReporter` at line 316 registers `addBinaryExpression` and checks:
1. Operator is `==` or `!=` (line 319) — **passes** for `filePathUrl == null`
2. Either side "looks like a path variable" via `_containsPathPattern` (line 325) — **passes** because `filePathUrl` contains `path`
3. Neither side has `.toLowerCase()` (line 331) — **passes** because null literal has no method call

The rule never checks whether either operand is a `NullLiteral`. A null check is never a case-sensitive comparison — case only matters when two string values are compared. The fix is to early-return when either operand is `NullLiteral`.

The same gap applies to comparisons against `.isEmpty` / `.isNotEmpty` (property access on the path variable, not a string-to-string comparison), though those are typically `!filePathUrl.isEmpty` (unary, not binary) and may not trigger this rule. The `== null` case is the confirmed path.

---

## Suggested Fix

In `runWithReporter` (line ~316), after the operator check and before `_containsPathPattern`, add:

```dart
// Null checks are not case-sensitive comparisons — skip them.
if (node.leftOperand is NullLiteral || node.rightOperand is NullLiteral) {
  return;
}
```

This filters out `x == null`, `null == x`, `x != null`, `null != x`.

---

## Fixture Gap

The fixture at `example*/lib/platforms/avoid_case_sensitive_path_comparison_fixture.dart` should include:

1. **Null check on path variable** — `filePathUrl == null` — expect NO lint
2. **Null check reversed** — `null == filePathUrl` — expect NO lint
3. **Not-null check** — `filePathUrl != null` — expect NO lint
4. **Actual string-to-string path comparison** — `filePath == otherPath` — expect LINT (existing)

---

## Changes Made

- `lib/src/rules/platforms/windows_rules.dart`: Added early-return for `NullLiteral` and `BooleanLiteral` operands in `runWithReporter`, before the `_containsPathPattern` check.
- `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`: Replaced placeholder with real fixture covering null checks (no lint) and string-to-string comparisons (lint).

---

## Tests Added

- `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`: 6 cases — 2 BAD (string-to-string comparisons fire), 4 GOOD (null checks don't fire), 1 GOOD (toLowerCase already applied).
- `test/rules/platforms/windows_rules_test.dart`: Existing instantiation + fixture-existence tests pass.

---

## Finish Report (2026-09-04)

The `avoid_case_sensitive_path_comparison` rule flagged `== null` and `!= null` expressions when the variable name contained a path-like substring (e.g. `filePathUrl`). Null guards are nullability checks, not case-sensitive string comparisons, and should never trigger this rule.

**Root cause:** `runWithReporter` checked for `==`/`!=` operators and path-like variable names but never excluded `NullLiteral` operands. A `filePathUrl == null` expression passed all guards because `null` has no `.toLowerCase()` call and `filePathUrl` matches the `_containsPathPattern` heuristic.

**Fix:** Added `_isBothSidesString` helper that uses the analyzer's type system (`staticType.isDartCoreString`) to verify both operands resolve to `String` before flagging. This eliminates all non-string false positives (null, bool, int, enum, object identity) in one check. Falls back to AST-level literal exclusion (`NullLiteral`, `BooleanLiteral`, `IntegerLiteral`) when static types are unavailable in unresolved code.

**Verification:** Scanned the original triggering file (`contacts/.../wikimedia_birthday_service.dart`) — zero `avoid_case_sensitive_path_comparison` hits post-fix. Previously reported a false positive at line 171.

**Fixture:** Replaced the empty placeholder with 9 concrete cases: 2 BAD (string-to-string path comparisons), 4 GOOD (null checks in all orientations), 2 GOOD (integer/boolean comparisons on path-named variables), 1 GOOD (toLowerCase already applied).

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 16.0.0-beta.2
- Dart SDK version: (current stable)
- custom_lint version: (current)
- Triggering project/file: `contacts/lib/service/wikimedia/wikimedia_birthday_service.dart:171`

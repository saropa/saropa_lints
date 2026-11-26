# BUG: `no_equal_nested_conditions` — fires on a condition re-checked after an `await`

**Status: Fixed**

Created: 2026-11-26
Rule: `no_equal_nested_conditions`
File: `lib/src/rules/code_quality/code_quality_control_flow_rules.dart` (line ~347)
Severity: False positive
Rule version: v4 (message tag) | Updated: v4.13.0

---

## Summary

A getter-based condition tested again after an `await` is reported as redundant. The state can change during the suspension, so the second check is a required guard.

---

## Attribution Evidence

```bash
grep -rn "'no_equal_nested_conditions'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_control_flow_rules.dart:335:    'no_equal_nested_conditions',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_control_flow_rules.dart:335`
**Rule class:** `NoEqualNestedConditionsRule` — registered in `lib/saropa_lints.dart:680`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
class Access {
  static bool get isEntitled => DateTime.now().second.isEven; // mutable state
}

Future<List<int>> load(Future<List<int>> Function() read) async {
  if (Access.isEntitled) {
    final List<int> rows = await read();
    // Access may have lapsed while read() ran.
    if (Access.isEntitled) { // LINT — but should NOT lint
      return rows;
    }
  }
  return <int>[];
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[no_equal_nested_conditions]` reported on the line marked LINT |

---

## AST Context

```
IfStatement (outer)
  └─ Block
      ├─ VariableDeclarationStatement (await)
      └─ IfStatement (inner)  ← condition reported
```

---

## Root Cause

`runWithReporter` (line ~347) compares `toSource()` of the conditions. `_NestedConditionChecker` (line ~362) only invalidates the match when a condition identifier was reassigned (`visitAssignmentExpression`). It does not track `await`, which lets other code change what a getter, field or method call returns.

---

## Suggested Fix

Add `visitAwaitExpression` to the checker. Once an `await` has been visited, skip a match whose condition reads anything other than a local variable or parameter (getter, field, method call).

---

## Fixture Gap

1. Getter condition re-checked after `await` — expect NO lint
2. Local `final bool` re-checked after `await` — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/code_quality/code_quality_control_flow_rules.dart`, rule version v5): after an `await`, `await for` or `yield` (including one later in an enclosing loop body), a repeated condition is reported only when nothing else can change its value: locals and parameters not written by a closure, final or const fields, literals, and members of immutable core values. A condition that itself awaits is not reported. The class DartDoc, which described a different rule, was replaced.

**Callbacks (hardening pass):** a check repeated inside a closure is treated like one after a suspension, because the closure may run after the outer check stopped holding; only stable conditions are reported there. A check after any call (method, function value or constructor) is not reported when the condition reads a local, parameter or field that a closure anywhere in the enclosing declaration writes, because the call may fire that stored callback synchronously. Field writes (`flag = x`, `this.flag = x`, `box.open = x`) now count as closure writes alongside local writes.

**Limits:** an `await` in a branch that cannot reach the inner check still marks it as suspended (a missed report, not a false positive). A closure invoked synchronously (`list.forEach`) is treated as possibly deferred, so a changeable condition repeated inside it is not reported. A plain call between the checks that changes a field directly, with no closure involved, is still reported.

Tests: `dart test test/rules/code_quality/no_equal_nested_conditions_recheck_after_await_test.dart test/rules/code_quality/code_quality_rules_test.dart test/rules/code_quality/batch_fp_fixes_2026_10_29_test.dart` - passed.

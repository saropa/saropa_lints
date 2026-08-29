# BUG: `no_equal_nested_conditions` — False positive when variable is reassigned between identical checks

**Status: Fixed**

Created: 2026-08-28
Rule: `no_equal_nested_conditions`
File: `lib/src/rules/code_quality/code_quality_control_flow_rules.dart` (line ~290)
Severity: False positive
Rule version: current
Suppression count in downstream project: **27** (100% FP rate in sample of 5)

---

## Summary

The rule detects two identical condition expressions in nested `if` statements
and flags the inner one as redundant. However, it does not track intervening
assignments to the variables in the condition. The most common FP pattern (all
27 suppressions, concentrated in ~18 search-matcher files) is:

```dart
if (x == null) { x = compute(); if (x == null) return null; }
```

The variable `x` is reassigned between the outer and inner checks, so the inner
check tests a **different value** and is not redundant.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'no_equal_nested_conditions'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_control_flow_rules.dart:290:    'no_equal_nested_conditions',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_control_flow_rules.dart:290`

---

## Reproducer

```dart
// LINT — but should NOT lint (false positive)
// x is reassigned between the two null checks
SearchQueryPart? query = searchTerm.getQueryMatchList(
  matchTermsPhone,
  appendToFindList: ':',
);

if (query == null) {
  if (searchTerm.contains(':')) {
    return null;
  }

  // x is REASSIGNED here — inner check tests the NEW value
  query = searchTerm.toSearchQuery('PHONE');

  if (query == null) { // inner check on reassigned variable — NOT redundant
    return null;
  }
}

// Pattern that SHOULD lint (no reassignment)
if (query == null) {
  doSomething();
  if (query == null) { // LINT — correct, this IS redundant
    return null;
  }
}
```

**Frequency:** Always — fires whenever two syntactically identical conditions
are nested, regardless of intervening assignments.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `query` was reassigned between the two `query == null` checks |
| **Actual** | `[no_equal_nested_conditions] Identical nested condition is always true/false at this point` reported on inner `if` |

---

## AST Context

```
IfStatement (query == null)              ← outer condition
  └─ Block
      └─ IfStatement (searchTerm.contains(':'))
      └─ ExpressionStatement
          └─ AssignmentExpression         ← query = searchTerm.toSearchQuery(...)
              └─ SimpleIdentifier (query)
              └─ MethodInvocation (searchTerm.toSearchQuery)
      └─ IfStatement (query == null)     ← inner condition (flagged) — tests NEW value
```

---

## Root Cause

### Hypothesis A: AST-equality check without assignment tracking

The rule compares the outer and inner conditions by AST structure (both are
`BinaryExpression` with `==` operator, left `SimpleIdentifier(query)`, right
`NullLiteral`). They are syntactically identical, so the rule flags the inner
one. The rule does not walk the statements between the two `if` nodes to check
for `AssignmentExpression` nodes that target any variable mentioned in the
condition.

---

## Suggested Fix

Before flagging an inner condition as redundant, walk the statements in the
outer `if`'s block that appear between the outer `if` and the inner `if`. For
each `AssignmentExpression` (including compound assignments), check whether the
left-hand side resolves to the same element as any `SimpleIdentifier` in the
condition expression. If a matching assignment exists, suppress the diagnostic —
the variable was reassigned and the inner check is semantically independent.

Also check for:
- `x = ...` (simple assignment)
- `x ??= ...` (null-aware assignment)
- Method calls that take `x` as a `ref` / output parameter (harder, lower priority)

---

## Fixture Gap

The fixture should include:

1. **Variable reassigned between identical nested checks** — expect NO lint
2. **No reassignment between identical nested checks** — expect LINT (existing)
3. **Variable reassigned via `??=`** — expect NO lint
4. **Different variable reassigned (not the one in condition)** — expect LINT
5. **Reassignment inside a nested block (inner if)** — may or may not reach; needs decision

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: 3.13.1
- Triggering project: `contacts` (d:\src\contacts)
- Downstream suppression count: 27 sites (~18 in search-matcher family)

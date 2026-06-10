# BUG: `no_equal_nested_conditions` — Variable Reassigned Between Outer and Inner Check

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `no_equal_nested_conditions`
File: `lib/src/rules/code_quality/code_quality_control_flow_rules.dart` (line ~278)
Severity: High — false positive on a common defensive guard pattern; forces `// ignore:` workaround
Rule version: v5 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule fires when an inner `if` condition is textually identical to an outer `if` condition, even
when a variable used in that condition is **reassigned between the two checks**. Because the inner
check tests the post-reassignment value, it is not redundant — it is a mandatory null guard on the
new value. The rule has no flow analysis for reassignment and fires purely on source-text equality.
Worked around in Saropa Contacts on 2026-06-09 with `// ignore: no_equal_nested_conditions`.

---

## Attribution Evidence

Attribution confirmed by the parent session before this report was filed (positive grep performed
by the calling agent). The rule is defined in `saropa_lints` at the location below. Because the
diagnostic owner is the analysis-server plugin (`_generated_diagnostic_collection_name_#N`) rather
than a sibling repo such as `saropa_drift_advisor`, negative attribution grep is not required.

```
# Positive — rule IS defined here
grep -rn "'no_equal_nested_conditions'" lib/src/rules/
# Result:
lib/src/rules/code_quality/code_quality_control_flow_rules.dart:278: 'no_equal_nested_conditions',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_control_flow_rules.dart:278`
**Rule class:** `NoEqualNestedConditionsRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

```dart
// Minimal reproducer — search-query normalization guard pattern.
// The outer guard is a fast-exit; the inner guard tests the NEW value
// produced by the intermediate reassignment.

void search(String? query) {
  if (query == null) return;           // outer guard — exits on the original null

  // Reassigns query; returns a nullable result (may be null after normalization)
  query = query.toSearchQuery('exact');

  if (query == null) return;           // LINT — but this tests the POST-reassignment value
                                       // The inner check is NOT equivalent to the outer check.
  doSearch(query);
}
```

**Frequency:** Always — fires whenever a variable used in the condition is reassigned to a
nullable expression between the outer and inner check.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the two `if (query == null)` checks test different values because `query` is reassigned between them |
| **Actual** | `[no_equal_nested_conditions] Inner condition is identical to an enclosing outer condition...` reported on the inner `if (query == null)` expression |

---

## AST Context

```
FunctionDeclaration (search)
  └─ BlockFunctionBody
      └─ Block
          ├─ IfStatement                         ← outer — expression: "query == null"
          │   └─ ReturnStatement
          ├─ ExpressionStatement                 ← reassignment of `query`
          │   └─ AssignmentExpression
          │       ├─ SimpleIdentifier (query)
          │       └─ MethodInvocation (.toSearchQuery('exact'))
          └─ IfStatement                         ← inner — expression: "query == null"
              │                                    ↑ node reported here (false positive)
              └─ ReturnStatement
```

---

## Root Cause

The detection logic is in `NoEqualNestedConditionsRule.runWithReporter` (line ~286) and its helper
visitor `_NestedConditionChecker` (line ~305).

`runWithReporter` calls `context.addIfStatement` and, for each outer `IfStatement`, captures the
outer condition as a raw source string (`node.expression.toSource()`, line ~291), then walks the
then-branch via `_NestedConditionChecker`.

`_NestedConditionChecker.visitIfStatement` (line ~313) compares inner and outer conditions with a
plain string equality check:

```dart
final String innerCondition = node.expression.toSource();
if (innerCondition == outerCondition) {
  reporter.atNode(node.expression, code);
}
```

This comparison is purely textual. The visitor never inspects the statements that appear between
the outer `IfStatement` and the inner one. Specifically, it does not check whether any
`AssignmentExpression` or `VariableDeclarationStatement` in the intervening statements assigns a
new value to any of the variables referenced by the condition string.

In the reproducer, `query` is reassigned at the `AssignmentExpression` node between the two
`IfStatement`s. After that assignment `query` holds a new value with independent nullability.
The inner `if (query == null)` therefore tests a different runtime value than the outer one, making
the report a false positive.

The diagnostic message's own rationale — "the outer condition already guarantees it" — is false
here: the outer condition guaranteed `query != null` for the *original* value only; the
reassignment invalidates that guarantee for every subsequent reference.

---

## Suggested Fix

Before reporting at the inner condition, scan the statement list of the enclosing block between
the outer `IfStatement`'s position and the inner `IfStatement`'s position for any statement that
assigns to (or declares and initialises) a variable that appears in the condition string.

Concretely, in `_NestedConditionChecker` (line ~305), collect the identifiers referenced in
`outerCondition` (by simple name match against the source string, or ideally by resolved
element). Then, while walking the then-branch or sibling statement list, track any
`AssignmentExpression` whose left-hand side matches one of those identifiers. If any such
assignment is found before the inner `IfStatement`, skip the report.

A lighter heuristic that covers the dominant case: before calling `reporter.atNode`, check whether
the immediate parent `Block` (if any) contains an `AssignmentExpression` or
`VariableDeclarationStatement` at a statement-list position between the outer and inner nodes.
If it does, suppress the diagnostic.

This mirrors the flow sensitivity that `avoid_context_across_await` already applies to its
post-await checks (context_rules.dart ~L177-220): when a value changes between the two checks,
the second check is not redundant.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/no_equal_nested_conditions_fixture.dart` should include:

1. **Variable reassigned between outer and inner check (same null test)** — expect NO lint.
   ```dart
   void example(String? q) {
     if (q == null) return;
     q = q.trim().isEmpty ? null : q.trim();  // reassigns q
     if (q == null) return;  // OK — tests post-reassignment value
     use(q);
   }
   ```

2. **Variable NOT reassigned — genuinely redundant inner check** — expect LINT.
   ```dart
   void example(String? q) {
     if (q == null) return;
     if (q == null) return;  // LINT — redundant, q not reassigned
     use(q);
   }
   ```

3. **Variable reassigned to non-nullable before inner check** — expect NO lint (the inner check
   is vacuously true, but it is still not the same runtime value the outer check tested).

4. **Nested block (inner check inside a nested `if`)** — ensure the visitor does not suppress
   reassignment tracking when the assignment is in a sibling branch, only when it is in the
   linear statement path leading to the inner check.

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: as used by Saropa Contacts on 2026-06-09
- custom_lint version: n/a (saropa_lints is a native analysis_server plugin)
- Triggering project/file: Saropa Contacts — search/query normalization utilities, 2026-06-09
- Workaround applied: `// ignore: no_equal_nested_conditions -- query is reassigned between checks`

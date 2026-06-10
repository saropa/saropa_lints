# BUG: `avoid_string_substring` — guard not recognized when the substring is in the ELSE branch of an `indexOf` ternary, or inside the `if` CONDITION itself

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (lines ~1039, ~1046)
Severity: False positive
Rule version: v3 | Since: (pre-v13) | Updated: v13.12.2

---

## Summary

`_isGuardedByLengthCheck` only recognizes a guard when the substring sits in the
**then**-branch:

- `IfStatement` is checked via `_isInThen` (then-statement only).
- `ConditionalExpression` is checked via `current.thenExpression == prev` only.

Two safe idioms are therefore missed:

1. **ELSE branch of an `indexOf` ternary.** `i < 0 ? s : s.substring(0, i)` and
   `i == -1 ? s : s.substring(0, i)` put the in-bounds substring in the *else*
   branch (the guard's purpose is to handle the "not found" case first). The
   else-expression is never matched against the condition.

2. **Substring inside the `if` CONDITION expression.** `if (i > 0 &&
   regex.hasMatch(s.substring(0, i)))` calls substring while *evaluating* the
   guard. The substring node's nearest enclosing `IfStatement` has it in the
   condition, not the then-statement, so `_isInThen` is false.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_string_substring'" lib/src/rules/
# => lib/src/rules/code_quality/code_quality_avoid_rules.dart:991:    'avoid_string_substring',

# Negative — not defined in the drift advisor
grep -rn "avoid_string_substring" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# => 0 matches (config-only toggle in its analysis_options.yaml:108)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:974`
**Rule class:** `AvoidSubstringRule` — registered in `lib/saropa_lints.dart:326`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
// Case 1 — ELSE branch of an indexOf ternary (plusIndex < 0 handled first).
String stripTag(String local) {
  final int plusIndex = local.indexOf('+');
  return plusIndex < 0 ? local : local.substring(0, plusIndex); // LINT — else branch, plusIndex >= 0 here
}

// Case 2 — ELSE branch keyed on `== -1`.
String firstLine(String raw) {
  final int newline = raw.indexOf('\n');
  return newline == -1 ? raw : raw.substring(0, newline); // LINT — else branch, newline is a valid index
}

// Case 3 — substring INSIDE the if condition.
void parseGroup(String rawOp) {
  final int dotIndex = rawOp.indexOf('.');
  if (dotIndex > 0 && _groupRegex.hasMatch(rawOp.substring(0, dotIndex))) { // LINT — dotIndex>0 guards it
    // ...
  }
}
```

**Frequency:** Always, for indexOf-result ternaries that put the substring in the else branch, and for substrings evaluated inside a bounds-checking condition.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the condition (`plusIndex < 0`, `newline == -1`, `dotIndex > 0`) bounds the substring argument; the substring runs only when the index is valid. |
| **Actual** | `[avoid_string_substring] substring() throws RangeError ...` reported at the `substring` call. |

---

## AST Context

```
// Case 1
ConditionalExpression  (plusIndex < 0 ? local : local.substring(0, plusIndex))
  ├─ condition:       BinaryExpression (plusIndex < 0)
  ├─ thenExpression:  SimpleIdentifier (local)            ← prev never equals this
  └─ elseExpression:  MethodInvocation (local.substring(0, plusIndex))  ← reported
```

`_isGuardedByLengthCheck` reaches the `ConditionalExpression` with
`prev == elseExpression`, but the branch at line 1046 only fires when
`current.thenExpression == prev`. The else case is never evaluated, so the
guard `plusIndex < 0` (which references the arg `plusIndex`) is ignored.

```
// Case 3
IfStatement
  ├─ condition:  ... && _groupRegex.hasMatch(rawOp.substring(0, dotIndex))  ← substring lives here
  └─ then:       Block { ... }
```

`_isInThen(ifStmt, prev)` returns false because `prev` ascends from the
*condition*, not the then-statement.

---

## Root Cause

`_isGuardedByLengthCheck` (lib/src/rules/code_quality/code_quality_avoid_rules.dart:1038–1051):

```dart
if (current is IfStatement && _isInThen(current, prev)) {
  if (_conditionGuardsLength(...) || _conditionInvolvesArgs(...)) return true;
} else if (current is ConditionalExpression &&
    current.thenExpression == prev) {            // <-- then only
  if (_conditionGuardsLength(...) || _conditionInvolvesArgs(...)) return true;
}
```

Defect A (else branch): when the substring is the else-expression, the
`ConditionalExpression` branch is skipped because `current.thenExpression !=
prev`. For an `indexOf`-derived index the safe placement is *normally* the else
branch (the then branch handles "not found"), so this is the common case, not
an edge case.

Defect B (in-condition): a substring evaluated inside the guard condition has
its nearest `IfStatement` in the condition position, so `_isInThen` is false and
the `_conditionInvolvesArgs(dotIndex)` check is never reached.

---

## Suggested Fix

For the `ConditionalExpression` branch, also accept the else-expression but key
the check on the **negation** of the condition. Practically, since
`_conditionInvolvesArgs` and `_conditionGuardsLength` both already accept any
mention of the arg name / receiver (they do not reason about polarity), the
simplest correct change is to accept either branch:

```dart
} else if (current is ConditionalExpression &&
    (current.thenExpression == prev || current.elseExpression == prev)) {
  if (_conditionGuardsLength(current.condition, receiverSource) ||
      _conditionInvolvesArgs(current.condition, argNames)) {
    return true;
  }
}
```

For the in-condition case, add a branch that detects the substring sitting
inside an `IfStatement`/`ConditionalExpression`/`WhileStatement` **condition**
and runs the same arg/receiver checks against that condition:

```dart
} else if (current is IfStatement &&
    _nodeWithin(current.expression, substringCall)) {
  if (_conditionGuardsLength(current.expression, receiverSource) ||
      _conditionInvolvesArgs(current.expression, argNames)) {
    return true;
  }
}
```

(`_nodeWithin` = walk `current.expression` to test ancestry of the substring
node; or compare source offsets.)

Note: the polarity-agnostic acceptance is consistent with how the rest of the
heuristic already works — it treats "the condition mentions the bounding
variable" as proof of intent, not a formal range proof. The else-branch and
in-condition cases are no weaker than the then-branch cases already accepted.

---

## Fixture Gap

The fixture should include:

1. `plusIndex < 0 ? local : local.substring(0, plusIndex)` — expect **NO** lint.
2. `newline == -1 ? raw : raw.substring(0, newline)` — expect **NO** lint.
3. `if (dotIndex > 0 && r.hasMatch(s.substring(0, dotIndex)))` — expect **NO** lint.
4. Control: `cond ? s.substring(0, i) : s` (substring in THEN, already handled) — expect **NO** lint (regression guard).
5. Control: `flag ? x : s.substring(0, i)` where `flag` is unrelated to `i` — expect **LINT** (must still fire when the condition does not bound the index).

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.9.0 <4.0.0
- analyzer: >=9.0.0 <13.0.0
- Triggering project/file: `d:\src\contacts` — `lib/utils/contact/matching/contact_match_normalizers.dart:225`, `lib/utils/contact/matching/contact_merged_view.dart:182`, `lib/utils/system/main_error_handling.dart:162`, `lib/database/file_backup/import/vcard_import_utils.dart:169`

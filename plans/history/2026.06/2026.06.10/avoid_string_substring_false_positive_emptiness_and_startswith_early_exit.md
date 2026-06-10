# BUG: `avoid_string_substring` — `isEmpty`/`isNotEmpty` and `startsWith` early-exit on the receiver are not recognized as length guards

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (lines ~1081, ~1139)
Severity: False positive
Rule version: v3 | Since: (pre-v13) | Updated: v13.12.2

---

## Summary

Two related gaps in the receiver-guard logic:

1. **`isEmpty` / `isNotEmpty` are not recognized.** `_conditionGuardsLength`
   only matches `receiver.startsWith(`, `receiver.endsWith(`, and
   `receiver.length <comparator>`. A guard written as
   `s.isEmpty ? s : s.substring(1)` or `if (s.isNotEmpty) s.substring(0, 1)`
   proves `s.length >= 1`, but the rule does not treat `.isEmpty`/`.isNotEmpty`
   as a length proof, so it fires.

2. **A `startsWith`/`length` guard expressed as an early-exit `return`/`continue`
   is not recognized.** `_conditionGuardsLength` is only consulted inside
   `IfStatement` *then*-branches and `ConditionalExpression` *then*-expressions.
   The early-exit path (`_hasPrecedingEarlyExitGuard`) checks **only** whether
   the guard condition mentions a substring *argument name* — it never calls
   `_conditionGuardsLength`, so a receiver guard like
   `if (!s.startsWith(prefix)) return;` followed by `s.substring(...)` is missed
   whenever the substring index is a literal or a property access.

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
// Case 1 — isEmpty ternary guard (literal index).
String weave(String t) {
  return t.isEmpty ? t : '${t[0].toLowerCase()}${t.substring(1)}'; // LINT — isEmpty proves len>=1
}

// Case 2 — isNotEmpty ternary guard.
String initial(String name) {
  return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?'; // LINT — isNotEmpty proves len>=1
}

// Case 3 — startsWith early-exit guard (literal index).
String? signalHandle(String fragment) {
  if (!fragment.startsWith('p/')) return null;
  return fragment.substring(2); // LINT — startsWith('p/') proves len>=2
}

// Case 4 — isEmpty early-return guard, then BOM strip.
String stripBom(String content) {
  if (content.isEmpty) return content;
  if (content.codeUnitAt(0) == 0xFEFF) {
    return content.substring(1); // LINT — content.isEmpty already returned
  }
  return content;
}
```

**Frequency:** Always, for `isEmpty`/`isNotEmpty` guards and for `startsWith`/`length` guards written as an early `return`/`continue`/`break` rather than wrapping the substring in the then-branch.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — each call is bounds-guarded by a receiver-level emptiness or `startsWith` check. |
| **Actual** | `[avoid_string_substring] substring() throws RangeError ...` reported at the `substring` call. |

---

## AST Context

```
// Case 3
MethodDeclaration (signalHandle)
  └─ Block
      ├─ IfStatement  (!fragment.startsWith('p/'))  thenStatement: return null
      └─ ReturnStatement
          └─ MethodInvocation  fragment.substring(2)   ← reported
```

The substring lives in a *sibling* statement after the guard `if`, not inside
the guard's `then`. `_isGuardedByLengthCheck` walks up to the enclosing `Block`
and calls `_hasPrecedingEarlyExitGuard`, which only inspects whether the guard
condition references a substring *argument* name (`{}` here, the arg is the
literal `2`). It never asks `_conditionGuardsLength` whether the guard proves
the receiver's length, so the `startsWith('p/')` proof is invisible.

---

## Root Cause

### Defect 1 — `_conditionGuardsLength` omits `isEmpty`/`isNotEmpty`

`lib/src/rules/code_quality/code_quality_avoid_rules.dart:1081–1102`:

```dart
final guardCheck = RegExp(
  '${RegExp.escape(receiverSource)}\\.(startsWith|endsWith)\\(',
);
if (guardCheck.hasMatch(source)) return true;
final lengthCheck = RegExp(
  '${RegExp.escape(receiverSource)}\\.length\\s*[<>=!]',
);
return lengthCheck.hasMatch(source);
```

`s.isEmpty` / `s.isNotEmpty` match neither pattern, so a ternary or if guarded
by emptiness is not recognized even though it proves `length >= 1` — sufficient
for any `substring(0, 1)` / `substring(1)`.

### Defect 2 — early-exit guard never consults `_conditionGuardsLength`

`_hasPrecedingEarlyExitGuard` (lines 1139–1153) only calls
`_conditionInvolvesArgs(stmt.expression, argNames)`. When the substring index
is a literal (`2`, `1`) the arg-name set is empty and the function bails at
`if (argNames.isEmpty) return false;` (line 1144). It should ALSO accept a
preceding early-exit whose condition `_conditionGuardsLength` proves for the
receiver — symmetric with the then-branch handling at lines 1042/1048.

These two defects, combined with the property-access arg gap (separate bug),
explain the downstream sites: `connection_prompt_model.dart:39` (isEmpty ternary),
`avatar_fly_overlay.dart:156` (isNotEmpty ternary),
`messaging_handle_url_parser.dart:125` (startsWith early-exit, literal index),
`csv_parser_utils.dart:97` (isEmpty early-return, literal index),
`public_holiday_name.dart:37` (isEmpty early-return, literal index),
`youtube_url_parsing_utils.dart:265` (startsWith early-exit on `segments[0]`, literal index).

---

## Suggested Fix

1. Add `isEmpty`/`isNotEmpty` to `_conditionGuardsLength`:

```dart
final emptinessCheck = RegExp(
  '${RegExp.escape(receiverSource)}\\.(isEmpty|isNotEmpty)\\b',
);
if (emptinessCheck.hasMatch(source)) return true;
```

   (Emptiness only proves `length >= 1`. That is sufficient for the common
   `substring(1)` / `substring(0, 1)` idioms; if the rule wants to be strict for
   larger literal indices it can gate this on the max constant substring index
   being `<= 1`. In practice every flagged site uses index 1.)

2. In `_hasPrecedingEarlyExitGuard`, also accept a preceding early-exit `if`
   whose condition is a receiver length/startsWith proof. Pass the receiver
   source down and add:

```dart
if (_conditionInvolvesArgs(stmt.expression, argNames) ||
    _conditionGuardsLength(stmt.expression, receiverSource)) {
  return true;
}
```

   and drop the `if (argNames.isEmpty) return false;` short-circuit (or guard it
   so it does not block the receiver-based path).

---

## Fixture Gap

The fixture should include:

1. `t.isEmpty ? t : t.substring(1)` — expect **NO** lint.
2. `name.isNotEmpty ? name.substring(0, 1) : '?'` — expect **NO** lint.
3. `if (!s.startsWith('p/')) return null;` then `s.substring(2)` — expect **NO** lint.
4. `if (s.isEmpty) return s;` then `s.substring(1)` in a later branch — expect **NO** lint.
5. Control: `s.substring(2)` with no emptiness/startsWith guard — expect **LINT**.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.9.0 <4.0.0
- analyzer: >=9.0.0 <13.0.0
- Triggering project/file: `d:\src\contacts` — `lib/data/quotes/connection_prompts/connection_prompt_model.dart:39`, `lib/utils/system/avatar_fly_overlay.dart:156`, `lib/utils/contact/web/messaging_handle_url_parser.dart:125`, `lib/utils/import/csv_parser_utils.dart:97`, `lib/models/system/public_holiday/public_holiday_name.dart:37`, `lib/service/youtube_api/youtube_url_parsing_utils.dart:265`

## Finish Report (2026-06-10)

Fixed in WS-1. `_conditionGuardsLength` now recognizes `isEmpty`/`isNotEmpty` (proves length>=1 for substring(1)/substring(0,1)). `_hasPrecedingEarlyExitGuard` now also consults `_conditionGuardsLength` (and a new regex-guard check) against the receiver and no longer short-circuits on an empty arg-name set, so a receiver-level `startsWith`/`isEmpty` early-exit guards a literal-index slice. Verified by the guard unit test (isEmpty/isNotEmpty ternary, startsWith early-exit, isEmpty early-return).

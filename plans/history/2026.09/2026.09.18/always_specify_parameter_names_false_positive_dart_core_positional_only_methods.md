# BUG: `always_specify_parameter_names` — Fires on `dart:core` Methods Whose Parameters Are Positional-Only and Cannot Be Named

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-18
Rule: `always_specify_parameter_names`
File: `lib/src/rules/code_quality/always_specify_parameter_names_rule.dart` (line ~39)
Severity: False positive — this is a design gap, not an edge case (see Root Cause)
Rule version: v1 | Since: not found in source | Updated: not found in source

---

## Summary

`always_specify_parameter_names` reports on calls to `String.substring(int start, [int? end])` and `String.replaceAll(Pattern from, String replace)` — both `dart:core` SDK methods whose parameter lists are declared entirely positional. Dart does not let a caller add named arguments to a call unless the *declaration* defines named parameters, and the SDK declaration cannot be changed by any caller. The rule's own suggested fix ("declare these parameters as named") is inapplicable to any SDK call, because the caller does not own the declaration.

---

## Attribution Evidence

```bash
$ cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'always_specify_parameter_names'" lib/src/rules/
lib/src/rules/code_quality/always_specify_parameter_names_rule.dart:60:    'always_specify_parameter_names',

$ grep -rn "'always_specify_parameter_names'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers below cite HEAD.

**Emitter registration:** `lib/src/rules/code_quality/always_specify_parameter_names_rule.dart:60` (`LintCode`)
**Rule class:** `AlwaysSpecifyParameterNamesRule` — defined at `lib/src/rules/code_quality/always_specify_parameter_names_rule.dart:39`. Exported via barrel `lib/src/rules/all_rules.dart:20` (`export 'code_quality/always_specify_parameter_names_rule.dart';`). Registered as a runnable rule via factory at `lib/saropa_lints.dart:234` (`AlwaysSpecifyParameterNamesRule.new,`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
void demo(String stmt) {
  // Both `start` and `end` are POSITIONAL in dart:core's declaration:
  //   String substring(int start, [int? end])
  // There is no `start:`/`end:` named form — this is a compile error:
  //   stmt.substring(start: 0, end: 10)
  final preview = stmt.substring(0, 10); // LINT (false positive)

  // Pattern.replaceAll(Pattern from, String replace) — also positional-only.
  final escaped = stmt.replaceAll('"', '""'); // LINT (false positive)
}
```

**Frequency:** Always, for any 2+ consecutive positional call to an SDK method whose confusable-typed parameters have no named form — `String.substring`/`replaceAll` are the most common, but the same shape recurs for any `dart:core`/`dart:*` API with 2+ adjacent same-type positional params.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the invoked method's declared parameter list is positional-only (no named-parameter form exists to switch to), particularly for methods outside the analyzed package (SDK, `dart:*`, or vendored pub.dev libraries). |
| **Actual** | `[always_specify_parameter_names] Call passes multiple consecutive positional arguments of the same type, risking a silent argument swap that the compiler cannot catch.` fires on `stmt.substring(0, _maxErrorSqlLength)` and two `.replaceAll(...)` calls at `lib/src/drift_debug_import.dart:121, 230, 255`. |

---

## AST Context

```
CompilationUnit (drift_debug_import.dart)
  └─ ... enclosing method/function
      └─ ExpressionStatement / VariableDeclarationStatement
          └─ MethodInvocation (stmt.substring(0, _maxErrorSqlLength))
              ├─ methodName: SimpleIdentifier ('substring')
              └─ argumentList: ArgumentList
                  ├─ IntegerLiteral (0)               ← positional arg 0
                  └─ SimpleIdentifier (_maxErrorSqlLength)  ← positional arg 1, same
                                                              confusable-type group
                                                              as arg 0 (both `int`)
                                                              ← rule reports here
                                                              (reporter.atNode(positionalArgs[start]))
```

---

## Root Cause

`_checkInvocation` (`always_specify_parameter_names_rule.dart:145-176`) is the sole gate before reporting. Its checks, in order:

1. `if (element is! ExecutableElement) return;` (line 154) — only confirms the call resolves to *some* executable element; does not distinguish SDK vs. package-owned.
2. `if (params.isEmpty) return;` (line 157) — only checks the element has *some* declared parameters.
3. `collectPositionalArgs` / `if (positionalArgs.length < 2) return;` (lines 160-163) — counts positional *arguments at the call site*, not whether the *declaration* offers a named alternative.
4. `buildTypeNames` + `findConfusableRuns` (lines 166-169, implemented in `always_specify_parameter_names_helpers.dart`) — groups by static type only (`normalizeTypeName`, `always_specify_parameter_names_helpers.dart:100-135`).

At no point does the rule inspect `element.library.isInSdk` (or equivalent), nor does it inspect the callee's own `FormalParameterList`/`ParameterElement.isNamed` to check whether *any* named form exists for these positions. Confirmed by `grep -n "substring\|replaceAll\|dart:core\|positional-only\|ExecutableElement\|isSdk\|library.isInSdk" lib/src/rules/code_quality/always_specify_parameter_names_helpers.dart` → the only match is an unrelated internal `String.substring` call inside the rule's own helper code (`always_specify_parameter_names_helpers.dart:136`), not a check on the *target* element.

This is not merely a missing edge case: the rule's stated purpose (`always_specify_parameter_names_rule.dart:18-25`, *"call sites... where named arguments could disambiguate"*) presupposes the callee *can* be called with named arguments. For a method whose SDK declaration is `String substring(int start, [int? end])`, no named form exists or can ever exist without breaking `dart:core`'s API — the rule's correction is unconditionally inapplicable, not merely unhelpful. This is a design gap in the detection condition (it never asks "can this call site legally be rewritten with named arguments"), not an edge case in an otherwise-sound heuristic.

---

## Suggested Fix

In `_checkInvocation` (`always_specify_parameter_names_rule.dart:145-176`), before collecting positional args, exclude invocations whose target `ExecutableElement` is declared in an SDK library (`element.library?.isInSdk == true`, or check the library's URI scheme is `dart:`) — those signatures are fixed by the language/SDK and can never accept named arguments the rule's own `correctionMessage` recommends adding. As a further refinement (optional, but closes the class of bug rather than one library): also skip when every one of the callee's declared parameters in the flagged positional run is `ParameterElement.isPositional` with no corresponding named alternative anywhere in the declaration, since a caller cannot introduce naming for a signature that doesn't define it — this covers third-party pub.dev packages with the same positional-only shape, not just `dart:core`.

---

## Fixture Gap

No dedicated fixture file exists for this rule (only `test/rules/code_quality/always_specify_parameter_names_test.dart` and `test/config/always_specify_parameter_names_config_test.dart`; searched `example*/` and `test/` for `always_specify_parameter_names_fixture.dart` — not found). `grep -n "substring\|replaceAll\|dart:core" test/rules/code_quality/always_specify_parameter_names_test.dart` also returned no matches, confirming no existing test covers SDK-call exemption.

Expected fixture path: `example/lib/code_quality/always_specify_parameter_names_fixture.dart`. Should include:

1. **`str.substring(0, 10)`** — expect NO lint (positional-only `dart:core` method).
2. **`str.replaceAll('a', 'b')`** — expect NO lint (positional-only `dart:core` method).
3. **A user-defined function with 2+ named-capable positional params of the same type**, e.g. `void createUser(String firstName, String lastName)` called as `createUser('Smith', 'John')` — expect LINT (existing documented bad-case behavior, to confirm the fix doesn't over-exempt).

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Environment

- saropa_lints version: 16.2.1 resolved (findings); 16.3.0 / HEAD (source reviewed for this report — confirmed unchanged for this rule since v16.2.1)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (findings from `saropa_lints scan` CLI / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/drift_debug_import.dart:121, 230, 255`; scan report `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`

---

## Finish Report (2026-09-18)

### Verdict

**Valid.** The report's root-cause analysis was confirmed by reading the rule
directly: `_checkInvocation` in
`lib/src/rules/code_quality/always_specify_parameter_names_rule.dart` never
inspected whether the callee's declaration is owned by the analyzed
package, so it fired on any 2+ consecutive same-type positional call —
including calls into `dart:core` (and any other SDK library) whose
parameter lists can never be changed by a caller. The rule's own
`correctionMessage` ("declare these parameters as named") is inapplicable
to any such call.

The report's *primary* suggested fix (skip when `element.library.isInSdk ==
true`) was adopted as-is — it directly targets the actual defect (caller
cannot edit the declaration) with a cheap, purely semantic (resolved
`LibraryElement`) check, no string/name heuristics involved.

The report's *optional* secondary refinement ("also skip when every
parameter in the flagged run is positional with no named alternative
anywhere in the declaration") was **not** adopted: on inspection it does not
discriminate anything additional here. Positional *arguments* only ever
bind to positional *parameters* in Dart — a positional argument can never
target a named parameter — so that condition is true for *every* positional
call the rule inspects (SDK or not), including the intentional true-positive
case (`createUser('Smith', 'John')`, where `firstName`/`lastName` are also
declared positional in that example). Adding it as written would have
silently disabled the rule entirely, a false negative. The real
discriminator is declaration *ownership*, which `isInSdk` already captures;
generalizing further to "vendored pub.dev libraries" (also mentioned in the
report) is a reasonable follow-up but out of scope for this minimal, targeted
fix — see Suggested Follow-up below.

### Root Cause

`_checkInvocation` (`always_specify_parameter_names_rule.dart`, originally
lines 145-176) gated only on argument shape (`element is ExecutableElement`,
non-empty `params`, 2+ positional args, confusable adjacent types) and never
checked whether the resolved target `ExecutableElement`'s declaring library
is external/SDK. `String.substring(int start, [int? end])` and
`Pattern.replaceAll(Pattern from, String replace)` in `dart:core` are
positional-only declarations that cannot be changed by any caller, making
the diagnostic's correction unconditionally inapplicable there.

### Fix

Added one early-return semantic guard in `_checkInvocation`, right after the
existing `params.isEmpty` check:

```dart
// The correctionMessage tells the developer to redeclare the flagged
// parameters as named — advice only actionable when the caller owns (can
// edit) the callee's declaration. SDK signatures like
// `String.substring(int start, [int? end])` and
// `Pattern.replaceAll(Pattern from, String replace)` are positional-only
// by design and fixed by the language/SDK: no named form exists or can
// ever exist, so flagging these calls is unconditionally unactionable
// (false positive found in review — see bugs/always_specify_parameter_names_
// false_positive_dart_core_positional_only_methods.md).
if (element.library.isInSdk) return;
```

`element.library` and `.isInSdk` are resolved analyzer `Element`/
`LibraryElement` members (`analyzer-12.1.0`); this is a fully semantic
check, consistent with the file's existing style (e.g. the
`_isAllowlistedConstructor` helper already inspects `enclosing.library.uri`
for the same class of reason). No string/name heuristics were introduced.

File changed: `lib/src/rules/code_quality/always_specify_parameter_names_rule.dart`.

### Tests Added

No fixture file previously existed for this rule (confirmed by the report),
and other rules in this codebase test SDK-resolution-dependent false
positives via the resolved-analyzer oracle harness
(`test/support/resolved_rule_harness.dart`) rather than fixture files, so
that pattern was followed here too (see e.g.
`test/rules/ui/prefer_typed_route_params_fp_test.dart` for precedent).

New file: `test/rules/code_quality/always_specify_parameter_names_fp_test.dart`
— three cases run through `reportedRuleCodes`/`runRuleResolved` with full
type resolution:

1. `stmt.substring(0, 10)` — expect NO `always_specify_parameter_names`.
2. `stmt.replaceAll('"', '""')` — expect NO `always_specify_parameter_names`.
3. `createUser('Smith', 'John')` against a user-defined
   `void createUser(String firstName, String lastName)` — expect the lint
   still fires (guards against over-exemption / false negatives).

### Test Results

```
dart analyze lib/src/rules/code_quality/always_specify_parameter_names_rule.dart \
  test/rules/code_quality/always_specify_parameter_names_fp_test.dart \
  test/rules/code_quality/always_specify_parameter_names_test.dart
→ No issues found!

dart test test/rules/code_quality/always_specify_parameter_names_fp_test.dart \
  test/rules/code_quality/always_specify_parameter_names_test.dart \
  test/config/always_specify_parameter_names_config_test.dart
→ +50: All tests passed!
```

(Two intermediate runs transiently failed to *load* due to concurrent,
unrelated syntax errors from other agents editing `code_quality_avoid_rules.dart`
and `core/async_rules.dart` in the same working tree at the time; both
cleared on their own before the final confirming run above, and neither
touched this rule's files.)

### Commits

Not committed — per task constraints, no git operations were performed;
changes are left in the working tree for the coordinator/user to commit.

### Suggested CHANGELOG bullet

- fix: `always_specify_parameter_names` no longer flags calls into SDK (`dart:*`) methods such as `String.substring`/`Pattern.replaceAll`, whose positional-only signatures cannot be changed by any caller

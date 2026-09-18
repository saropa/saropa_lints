# BUG: `avoid_stack_trace_in_production` — Guard Detection Only String-Matches the `IfStatement`'s Own Condition, Missing Indirection Through a Local Variable and a Helper Function

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-18
Rule: `avoid_stack_trace_in_production`
File: `lib/src/rules/security/security_network_input_rules.dart` (line ~4773)
Severity: False positive
Rule version: v1 | Since: not found in source | Updated: not found in source

---

## Summary

`avoid_stack_trace_in_production` reports on `print(stack)` inside `if (includeTrace) { ... }` in `error_logger.dart`. `includeTrace` is `includeStack && _isDebugEnvironment()`, and `_isDebugEnvironment()` is `!bool.fromEnvironment('dart.vm.product', defaultValue: false)` — `dart.vm.product` is `true` in every release/profile build, so `print(stack)` is genuinely unreachable in production. The rule's debug-guard detector only string-matches the enclosing `IfStatement`'s own condition text against three literal substrings (`kDebugMode`, `kProfileMode`, `!kReleaseMode`); it does not follow the condition through a local `bool` variable, and would not recognize `bool.fromEnvironment('dart.vm.product')` even if it did follow the indirection, since that pattern is not in its substring list at all.

---

## Attribution Evidence

```bash
$ cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'avoid_stack_trace_in_production'" lib/src/rules/
lib/src/rules/security/security_network_input_rules.dart:4796:    'avoid_stack_trace_in_production',

$ grep -rn "'avoid_stack_trace_in_production'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
lib/src/error_logger.dart:6:///  (avoid_stack_trace_in_production).
lib/src/error_logger.dart:92:  /// debug builds (avoid_stack_trace_in_production). Logging never throws.
```

The two matches in `saropa_drift_advisor` are doc-comment mentions of the rule's *name* (the codebase's own developers documenting which lint the guard is defending against) — not a rule registration or `LintCode`. No `LintCode('avoid_stack_trace_in_production', ...)` or rule class exists downstream; positive attribution is against `saropa_lints` only.

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers below cite HEAD.

**Emitter registration:** `lib/src/rules/security/security_network_input_rules.dart:4796` (`LintCode`)
**Rule class:** `AvoidStackTraceInProductionRule` — defined at `lib/src/rules/security/security_network_input_rules.dart:4773`. Exported via barrel `lib/src/rules/all_rules.dart:91` (`export 'security/security_network_input_rules.dart';`). Registered as a runnable rule via factory at `lib/saropa_lints.dart:2727` (`AvoidStackTraceInProductionRule.new,`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

Note: the doc comment immediately above `AvoidStackTraceInProductionRule` (`security_network_input_rules.dart:4749-4771`) describes secure-storage error handling ("Secure storage operations can fail...", "GOOD: try { ... } on PlatformException catch (e) {...}") — this reads as a copy/paste artifact from a neighboring rule (likely `require_secure_storage_error_handling`) and does not document this rule's actual behavior. Flagging for awareness; not the subject of this report.

---

## Reproducer

```dart
bool _isDebugEnvironment() =>
    !bool.fromEnvironment('dart.vm.product', defaultValue: false);

void logError(Object error, StackTrace stack, {bool includeStack = true}) {
  final bool includeTrace = includeStack && _isDebugEnvironment();
  print(error);
  if (includeTrace) {
    print(stack); // LINT (false positive) — unreachable when dart.vm.product is true
  }
}
```

**Frequency:** Always, whenever the guarding condition is a local variable (rather than the `if`'s own inline expression) and/or derives from `bool.fromEnvironment('dart.vm.product')` rather than the three literal Flutter constants the rule recognizes.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `print(stack)` is reachable only when `includeTrace` is `true`, which requires `_isDebugEnvironment()` to be `true`, which is `false` in every build where `dart.vm.product` is `true` (all release/profile builds). |
| **Actual** | `[avoid_stack_trace_in_production] Stack trace exposed to user-visible output. ...` fires on `print(stack)` at `error_logger.dart:125`. |

---

## AST Context

```
CompilationUnit (error_logger.dart)
  └─ ClassDeclaration / top-level function (errorCallback's returned closure)
      └─ Block
          ├─ VariableDeclarationStatement
          │   └─ VariableDeclaration (includeTrace = includeStack && _isDebugEnvironment())
          ├─ ExpressionStatement (developer.log(..., stackTrace: includeTrace ? stack : null))
          └─ IfStatement (if (includeTrace) { ... })
              ├─ expression: SimpleIdentifier ('includeTrace')   ← condition the rule string-matches
              └─ thenStatement: Block
                  └─ ExpressionStatement
                      └─ MethodInvocation (print(stack))  ← node the rule reports on
                          └─ argumentList → SimpleIdentifier ('stack'), staticType StackTrace
                                            (matches `_hasStackTraceArg` via typeName == 'StackTrace')
```

---

## Root Cause

`AvoidStackTraceInProductionRule.runWithReporter` (`security_network_input_rules.dart:4819-4854`) reports on `print`/`debugPrint`/non-`dart:developer` `log` calls whose arguments satisfy `_hasStackTraceArg` (line 4840, confirmed true here — `stack`'s static type is `StackTrace`) **unless** `_isInsideDebugGuard(node)` returns true (line 4843).

`_isInsideDebugGuard` (`security_network_input_rules.dart:4896-4914`):

```dart
bool _isInsideDebugGuard(AstNode targetNode) {
  AstNode? current = targetNode.parent;
  while (current != null) {
    if (current is IfStatement) {
      final String condition = current.expression.toSource();
      if (condition.contains('kDebugMode') ||
          condition.contains('kProfileMode') ||
          condition.contains('!kReleaseMode')) {
        if (_isDescendantOf(targetNode, current.thenStatement)) {
          return true;
        }
      }
    }
    if (current is FunctionBody) break;
    current = current.parent;
  }
  return false;
}
```

Two independent gaps, both present in this one finding:

1. **No indirection through a local variable.** `current.expression.toSource()` (line 4899) takes the literal source text of the `IfStatement`'s own condition expression. Here that expression is the bare identifier `includeTrace` — its source text is `"includeTrace"`, which contains none of the three substrings checked. The detector never resolves `includeTrace`'s declaration (`VariableDeclaration` initializer `includeStack && _isDebugEnvironment()`) to see what it's actually guarded by; it only inspects the `if` condition's own syntax.
2. **No recognition of `bool.fromEnvironment('dart.vm.product')` even directly.** The substring checklist (lines 4900-4902) is a closed set of exactly three Flutter-specific constant names/negations: `kDebugMode`, `kProfileMode`, `!kReleaseMode`. It has no branch for `bool.fromEnvironment('dart.vm.product')` (the Dart-VM-level, non-Flutter-dependent equivalent used here, appropriate since this is a `dart:` package rather than a Flutter widget package) or its common wrapped forms (`!bool.fromEnvironment('dart.vm.product')`, `kReleaseMode` itself defined in `package:flutter/foundation.dart` as exactly this expression). Even if gap 1 were fixed to trace through `includeTrace` to its initializer `includeStack && _isDebugEnvironment()`, the detector would then need to resolve `_isDebugEnvironment()` — a function call, not an inline condition — to its body, which gap 2 also does not support.

---

## Suggested Fix

In `_isInsideDebugGuard` (`security_network_input_rules.dart:4896-4914`):

1. When the `IfStatement`'s condition is a `SimpleIdentifier` (or contains one as an operand) resolving to a local `bool` variable, resolve that variable's `VariableDeclaration.initializer` and recursively apply the same substring/pattern check to it (bounded recursion depth, e.g. 2-3 levels, to avoid runaway traversal) instead of only checking `current.expression.toSource()` directly.
2. Extend the pattern list beyond the three literal Flutter constants to also recognize `bool.fromEnvironment('dart.vm.product')` (with or without a leading `!`) as a debug/non-production guard — this is the Dart-VM-native equivalent of `kReleaseMode`/`kDebugMode` and is the correct pattern for non-Flutter `dart:` packages (like this one) that cannot depend on `package:flutter/foundation.dart`.
3. Optionally, follow one level of user-defined function call (e.g. `_isDebugEnvironment()`) by resolving to the function's declaration and checking its body/expression against the same patterns — this closes the gap for exactly the two-hop indirection (`includeTrace` → `_isDebugEnvironment()` → `bool.fromEnvironment(...)`) seen here, though a single-hop fix (item 1) plus item 2 would already resolve variants with only one layer of indirection.

---

## Fixture Gap

Fixture at `example/lib/security/avoid_stack_trace_in_production_fixture.dart` (229 lines) covers a direct `if (kDebugMode) { ... }` guard (line ~163, expect NO lint) but has no case for `bool.fromEnvironment('dart.vm.product')`, nor for guard indirection through a local variable or a helper function (`grep -n "bool.fromEnvironment|kDebugMode|includeTrace|_isDebugEnvironment|helper"` confirms only the direct `kDebugMode` case exists). Should add:

1. **`if (!bool.fromEnvironment('dart.vm.product')) { print(stack); }`** — expect NO lint (direct SDK-level guard, no Flutter dependency).
2. **`final includeTrace = !bool.fromEnvironment('dart.vm.product'); if (includeTrace) { print(stack); }`** — expect NO lint (single-hop variable indirection; this bug's exact shape once `_isDebugEnvironment()` is inlined).
3. **`bool isDebug() => !bool.fromEnvironment('dart.vm.product'); if (isDebug()) { print(stack); }`** — expect NO lint (function-call indirection, tests item 3 of the suggested fix if implemented).

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
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/error_logger.dart:125`; scan report `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`

---

## Finish Report (2026-09-18)

**Verdict:** Valid false positive. Both gaps in the report are real and both were fixed.

**Root cause:** `_isInsideDebugGuard` in `AvoidStackTraceInProductionRule`
(`lib/src/rules/security/security_network_input_rules.dart`) only looked at
the enclosing `IfStatement`'s own condition source text, checked against a
closed set of three Flutter-specific substrings (`kDebugMode`,
`kProfileMode`, `!kReleaseMode`). It never resolved a guarding local
variable to its initializer, never resolved a guarding helper-function call
to its body, and had no pattern for the Dart-VM-native
`bool.fromEnvironment('dart.vm.product')` guard used by non-Flutter `dart:`
packages. All three gaps applied to the reporter's exact repro
(`includeTrace` → `includeStack && _isDebugEnvironment()` →
`!bool.fromEnvironment('dart.vm.product', defaultValue: false)`).

**Fix:** Replaced the single-level text check with
`_conditionGuardsDebugOnly(Expression, {depth})`, a bounded-recursion
(max 3 hops, `_maxGuardIndirectionDepth`) walk that:
- still matches `kDebugMode` / `kProfileMode` / `!kReleaseMode` by substring
  (unchanged), plus a new pattern for `!bool.fromEnvironment('dart.vm.product'...)`
  (only when negated — the un-negated form guards for production, not debug,
  and must keep firing);
- follows a `SimpleIdentifier` condition to its local variable's
  initializer via `_resolveIdentifierToInitializer` (element-identity match
  against `VariableDeclaration.declaredFragment?.element`, scoped to the
  nearest enclosing `Block`);
- follows a zero-arg, unqualified `MethodInvocation` to its declaration's
  body expression via `_resolveCallToBodyExpression` /
  `_DebugGuardFunctionBodyFinder` (handles both `=> expr` and single
  `return expr;` bodies; multi-statement bodies are conservatively not
  followed);
- recurses into `BinaryExpression`/`PrefixExpression`/`ParenthesizedExpression`
  operands so indirection buried inside a larger boolean expression (e.g.
  `includeStack && _isDebugEnvironment()`) is still found.

Added imports: `package:analyzer/dart/ast/visitor.dart`,
`package:analyzer/dart/element/element.dart`.

**Files changed:**
- `lib/src/rules/security/security_network_input_rules.dart` — rule fix
  (`_isInsideDebugGuard`, new `_conditionGuardsDebugOnly`,
  `_conditionTextIsDebugGuard`, `_resolveIdentifierToInitializer`,
  `_resolveCallToBodyExpression`, `_dartVmProductDebugGuardPattern`, and
  the new top-level `_DebugGuardFunctionBodyFinder` visitor).
- `example/lib/security/avoid_stack_trace_in_production_fixture.dart` —
  added `_falsePositive4`..`_falsePositive7` (direct `dart.vm.product`
  guard, single-hop variable indirection, function-call indirection, and
  the exact two-hop shape from the report) plus `_bad4` (un-negated
  `dart.vm.product` check, which must still lint — guards a true negative
  didn't get swallowed by the fix).
- `test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart`
  (new) — 6 resolved-rule-harness tests covering the control case, the
  direct guard, variable indirection, function indirection, the two-hop
  bug-report shape, and the un-negated-must-still-fire case.

**Tests:**
- `dart analyze lib/src/rules/security/security_network_input_rules.dart example/lib/security/avoid_stack_trace_in_production_fixture.dart test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart` → No issues found.
- `dart test test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart` → All 6 tests passed.
- `dart test test/rules/security/security_rules_test.dart` → All 128 tests passed (fixture-existence/metadata group unaffected).
- (Transient, unrelated: two other in-flight concurrent edits — `code_quality_avoid_rules.dart` and `async_rules.dart` — briefly broke the whole-package compile while `dart test` was run; both were fixed by their owning agents mid-session and are unrelated to this rule.)

**Commits:** none created by this agent (per task constraints — no git operations performed).

---

## Finish Report Amendment (2026-09-18, V2 — sound guard analysis)

An Opus review caught a correctness regression in the V1 fix above, confirmed
by running the harness against the cases it named: `_conditionGuardsDebugOnly`
treated `&&` and `||` alike ("either operand qualifies") and had `!` recurse
without inverting, and applied the `kDebugMode`/`kReleaseMode`/`dart.vm.product`
text checks to the WHOLE condition text (including compound expressions and
resolved helper bodies), not just to atoms. Consequence: several shapes that
are NOT sound debug guards were silently suppressed, e.g.
`if (!isDebug()) print(s);` (guarantees production, not debug),
`if (verbose || isDebug()) print(s);` (unguarded `||` operand),
`final release = !isDebug(); if (release) print(s);`,
`if (x != isDebug()) print(s);` (unmodeled `!=`), and a helper
`bool isRelease() => bool.fromEnvironment('dart.vm.product') || !kDebugMode;`
used as `if (isRelease())` (the old whole-text `contains('kDebugMode')` check
matched the helper's body regardless of where in the expression it sat).

**Fix (ported from `GuardDebuggerAgainstTestEnvironmentRule`, commit
66ac1a95, which fixed the identical class of bug for
`guard_debugger_against_test_environment`):** replaced the single
`_conditionGuardsDebugOnly` predicate with a pair of mutually recursive,
dual predicates:
- `_guaranteesDebug(Expression, {depth})` — true when the condition being
  TRUE proves debug/non-production (a sound guard for the `then` branch).
- `_impliedByProduction(Expression, {depth})` — true when being in
  PRODUCTION forces the expression true; the dual used under `!`.

Both recurse ONLY into `ParenthesizedExpression`, `PrefixExpression` (`!`,
which swaps to the other predicate), and `BinaryExpression` with `&&`/`||`
(`&&` needs only one operand to guarantee its predicate — `OR` of the two
recursive calls; `||` needs every operand — `AND` of the two). Any other
binary operator (`==`, `!=`, ...) returns `false` immediately rather than
falling through to a text scan. `_isDebugAtom`/`_isProductionAtom` (the old
substring/regex checks, now split into a debug vocabulary —
`kDebugMode`/`kProfileMode` — and a production vocabulary —
`kReleaseMode`/unnegated `bool.fromEnvironment('dart.vm.product')`) are
applied ONLY to atoms reached after that unwrapping, never to a compound
expression's full source text. Local-variable and helper-call indirection
(`_resolveIndirection`, still bounded by `_maxGuardIndirectionDepth = 3`,
which now only counts indirection hops — not paren/`&&`/`||` unwrapping)
re-applies the SAME predicate (`_guaranteesDebug` or `_impliedByProduction`)
to whatever the identifier/call resolves to, so both directions of
indirection stay sound.

Also applied the review's optional nits:
- `_resolveIdentifierToInitializer` now walks outward through every
  enclosing `Block` (up to 50 hops, stopping at `FunctionBody`) instead of
  only the innermost one.
- `_DebugGuardFunctionBodyFinder` now throws a private
  `_DebugGuardFunctionFound` sentinel once it matches the target
  declaration, unwinding the visitor immediately instead of continuing to
  walk the rest of the compilation unit.

**Files changed (this amendment):**
- `lib/src/rules/security/security_network_input_rules.dart` — replaced
  `_conditionGuardsDebugOnly`/`_conditionTextIsDebugGuard` with
  `_guaranteesDebug`/`_impliedByProduction`/`_isDebugAtom`/
  `_isProductionAtom`/`_resolveIndirection`/`_dartVmProductPattern`;
  widened `_resolveIdentifierToInitializer`'s block search; added early
  stop to `_DebugGuardFunctionBodyFinder` via the new
  `_DebugGuardFunctionFound` exception class.
- `example/lib/security/avoid_stack_trace_in_production_fixture.dart` —
  added `_bad5`..`_bad10` (negated helper call, `||` with an unguarded
  operand, a variable holding a negated guard, an unmodeled `!=`, a
  variable initializer that's `||` with an unguarded operand, and a
  helper whose body is a production check) plus the `_isRelease()` helper
  they use — all `expect_lint`, all previously silenced by the V1 bug.
- `test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart`
  — added a second group, "sound guard analysis (&&/||/!)", with 9 new
  tests: the 6 true-positive cases named by the review, plus 3 controls
  confirming the fix didn't overcorrect (`!kReleaseMode` still suppresses,
  `includeStack && isDebug()` — one guarded `&&` operand — still
  suppresses).

**Tests (V2, foreground):**
- `dart analyze` on the 3 touched files → No issues found.
- `dart test test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart`
  → All 14 tests passed (5 original no-lint/control cases + 9 new).
- `dart test test/rules/security/security_rules_test.dart` → All 128 tests
  passed.
- Transient, unrelated: two other in-flight concurrent edits
  (`platforms/windows_rules.dart`, briefly, and earlier in the session
  `code_quality_avoid_rules.dart`/`core/async_rules.dart`) intermittently
  broke the whole-package compile while these commands ran; each was
  fixed by its owning agent within ~15s and is unrelated to this rule.

**Commits:** none created by this agent (per task constraints — no git
operations performed; the working tree was also switched to branch
`fix/ci-toggle-if-and-template-parity` by another agent's git operation
mid-session — uncommitted work here was unaffected).

---

## Finish Report Amendment (2026-09-18, V3 — reassignment + exact atoms)

A second Opus review, again verified by running code, confirmed the V2
`&&`/`||`/`!` fix but found two more soundness gaps in the same rule:

1. **Reassigned locals were trusted.** `_resolveIdentifierToInitializer`
   traced a `SimpleIdentifier` back to its `VariableDeclaration`'s
   initializer with no check that the local hadn't since been reassigned,
   so `var t = isDebug(); t = true; if (t) print(s);` and
   `bool t = kDebugMode; if (v) t = true; if (t) print(s);` were both
   silently suppressed even though `t` is `true` (production/unrelated)
   at the `if`, not whatever the initializer said.
2. **Atom checks still used `toSource().contains(...)`.** So
   `bool hide(bool b) => !b; if (hide(kDebugMode)) print(s);` counted as
   a guard — `kDebugMode` merely appears as an ARGUMENT to an unrelated
   1-arg call (not followed by indirection, which only resolves 0-arg
   calls), but the substring check matched it anywhere in the condition's
   source text regardless of position.

**Fix (1), ported from `AvoidCaseSensitivePathComparisonRule`'s
`_findLocalDeclaration`/`_reassignedBetween`/`_ReassignmentBetweenVisitor`
in `lib/src/rules/platforms/windows_rules.dart`:**
`_resolveIdentifierToInitializer` now calls a new `_findLocalDeclaration`,
which trusts a `final`/`const` declaration unconditionally (Dart forbids
reassigning it) and, for a mutable `var`/typed local, additionally
requires `_reassignedBetween` (scanning the enclosing `FunctionBody` via a
new `_DebugGuardReassignmentVisitor`) to find no assignment to that
element between the declaration and the identifier's use-site offset.
Either condition failing returns `null` (refuse to trace through) rather
than risk a stale initializer.

**Fix (2):** replaced the two `toSource().contains(...)` atom checks with
exact-shape matchers:
- `_isBuildModeConstant(atom, name)` — `atom` must be exactly a bare
  `SimpleIdentifier` or namespace-qualified `PrefixedIdentifier` named
  `kDebugMode`/`kProfileMode`/`kReleaseMode`. When it resolves, it's
  rejected only if it resolves to a DIFFERENT `package:flutter/...`
  library than `foundation.dart` (a real Flutter symbol that merely
  shares the name); unresolved, or resolved to a local/non-Flutter
  declaration, is accepted by name — required because this package's own
  example fixtures and resolved-rule-harness tests mock these constants
  locally (the example package has no Flutter dependency, so they can
  never resolve to the real `package:flutter/foundation.dart`); a
  stricter "must resolve to foundation.dart or be entirely unresolved"
  reading was tried first and broke every existing fixture/test case that
  uses a local mock — see the dev-loop note below.
- `_isDartVmProductCheck(atom)` — `atom` must be exactly
  `bool.fromEnvironment('dart.vm.product')`. Discovered mid-fix (dev-loop
  note below) that `bool.fromEnvironment` is a `const factory`
  constructor of SDK `bool`, not a static method, so the analyzer parses
  a call to it as an `InstanceCreationExpression` (`constructorName.type`
  = `bool`, `constructorName.name` = `fromEnvironment`), never a
  `MethodInvocation` — the first version of this matcher checked for
  `MethodInvocation` and consequently matched NOTHING, which silently
  broke every existing no-lint case using this guard until caught by a
  full test run and root-caused with a standalone AST-dump script.

Both `_isDebugAtom`/`_isProductionAtom` now call these exact matchers
instead of a substring scan. `_flagComparison` (unchanged from what would
have been the optional nit) models `<flag> == true`/`!= false` (same as
`<flag>`) and `<flag> == false`/`!= true` (same as `!<flag>`) for a
boolean-literal comparison on either side, so `kDebugMode == true` and
`kReleaseMode == false` are recognized as guards.

**Dev-loop note:** the first attempt at fix (2) passed `dart analyze` but
FAILED 9 of the existing no-lint regression tests (the rule started
firing on every previously-suppressed case). Root-caused by writing a
standalone AST-dump script (bypassing the package, since the tree was
mid-edit by other concurrent agents at the time) that printed the actual
node type/shape of `bool.fromEnvironment('dart.vm.product')` — confirming
it's an `InstanceCreationExpression`, not a `MethodInvocation` — and
separately that the strict foundation.dart-only resolution check rejected
every locally-mocked `kDebugMode`/`kReleaseMode` in this package's own
fixtures. Both were fixed and the full targeted suite re-run green before
reporting.

**Files changed (this amendment):**
- `lib/src/rules/security/security_network_input_rules.dart` —
  `_findLocalDeclaration`/`_reassignedBetween`/
  `_DebugGuardReassignmentVisitor` (new, reassignment soundness);
  `_isBuildModeConstant`/`_isDartVmProductCheck` (new, exact-shape atom
  matchers replacing the substring checks); `_flagComparison` (models
  `== true`/`== false`/`!= true`/`!= false`); `_DebugGuardFunctionBodyFinder`
  rewritten from exception-based early-stop (`_DebugGuardFunctionFound`,
  removed) to a `_found` flag checked at the top of overridden
  `visitCompilationUnit`/`visitClassDeclaration`/`visitFunctionDeclaration`/
  `visitMethodDeclaration` methods — no other rule in this package uses
  exceptions for control flow. Also fixed an unrelated pre-existing
  analyzer-12.1.0 API mismatch surfaced while writing
  `visitClassDeclaration`: `ClassDeclaration.members` no longer exists in
  this analyzer version — members live at `ClassDeclaration.body.members`
  now (a `ClassBody` wrapper was added upstream).
- `example/lib/security/avoid_stack_trace_in_production_fixture.dart` —
  added `_bad11`/`_bad12` (reassigned-local cases, one unconditional, one
  conditionally reassigned), `_bad13` + `_hide()` helper (recognized name
  as a call argument, not the condition), and `_falsePositive8`/
  `_falsePositive9` (`kDebugMode == true`, `kReleaseMode == false`); added
  top-level `const kReleaseMode = false;` (mirroring the existing
  `const kDebugMode = true;` mock, needed by the new cases).
- `test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart`
  — added a third group, "reassignment and exact atoms", with 7 new
  tests: the 3 true-positive cases from the review (unconditional
  reassignment, conditional reassignment, argument-not-condition) plus 4
  controls (a `final` local's guard still holds; `kDebugMode == true` and
  `kReleaseMode == false` still suppress; `kDebugMode != true` still
  fires).

**Tests (V3, foreground):**
- `dart analyze` on the 3 touched files → No issues found.
- `dart test test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart test/rules/security/security_rules_test.dart`
  → All tests passed (21 in the debug-guard file: 5 + 9 + 7 across the
  three groups; 128 in security_rules_test.dart).

**Commits:** none created by this agent (per task constraints — no git
operations performed).

---

## Finish Report Amendment (2026-09-18, V4 — real-Flutter blocker + 2 nits)

A third Opus review, verified against the real Flutter SDK at
`/Users/craighathaway/Documents/flutter`, found a severe regression in the
V3 fix plus two smaller soundness nits.

**1. BLOCKER — real Flutter guards were flagged.** V3's
`_isBuildModeConstant` accepted a Flutter-resolved atom only when its
library URI was exactly `package:flutter/foundation.dart`. But
`kDebugMode`/`kProfileMode`/`kReleaseMode` are DECLARED in
`package:flutter/src/foundation/constants.dart` — `foundation.dart` only
`export`s them — and `element.library.uri` reports the DECLARING library,
never the re-exporting one. So a real
`import 'package:flutter/foundation.dart'; if (kDebugMode) print(s);` (the
canonical guard in every Flutter app) resolved `kDebugMode`'s library to
`src/foundation/constants.dart`, which is neither `null` (unresolved) nor
`foundation.dart` — so V3 rejected it and the rule fired on the single
most common real-world use of this exact guard.

**Fix:** `_isBuildModeConstant` now accepts a Flutter-resolved atom when
its library URI is `package:flutter/foundation.dart` **or** starts with
`package:flutter/src/foundation/`.

**Regression test (must fail on V3, pass on V4):** rather than hardcode a
path to the real Flutter checkout (fragile across machines/CI), built a
fake `flutter` package on disk with the SAME shape as the real SDK — a
`lib/foundation.dart` barrel that `export`s `lib/src/foundation/constants.dart`,
which is where the fake `kDebugMode`/`kProfileMode`/`kReleaseMode` are
actually declared — plus a `.dart_tool/package_config.json` pointing the
`flutter` package name at it, so `import 'package:flutter/foundation.dart';`
resolves for real. New helper
`_runRuleResolvedWithFakeFlutter`/`_FakeFlutterRuleContext` in the test
file, modeled on `_runRuleResolvedInProject`/`_GateTestRuleContext` in
`test/rules/resources/db_yield_rules_test.dart` (that harness only needs a
`pubspec.yaml` since its rules gate on pubspec text, never resolving
`package:flutter/...`, so it doesn't by itself cover this). Confirmed this
reproduces the exact failure: ran the new tests against the V3 code first
— `kDebugMode`, `!kReleaseMode`, and `foundation.kDebugMode` (namespaced
import) all incorrectly fired — then applied the fix and re-ran green.

**2. Loop-carried reassignment (nit).** `_reassignedBetween`'s offset-window
text scan can't see control flow: `var t = isDebug(); for (final x in xs)
{ if (t) print(s); t = x; }` reassigns `t` AFTER the guarded use in source
order (on the next iteration), so the window-based check found no
reassignment and wrongly trusted the initializer.

**Fix:** dropped the mutable-local indirection path entirely —
`_findLocalDeclaration` now only traces a `final`/`const` local, exactly
matching `AvoidCaseSensitivePathComparisonRule`'s stance in
`windows_rules.dart`, never a plain `var`/typed mutable one, regardless of
whether a reassignment is textually visible. Removed the now-dead
`_reassignedBetween` and `_DebugGuardReassignmentVisitor` (the whole
reassignment-window mechanism from V3, superseded by "never trust a
mutable local" rather than "trust it if no reassignment is visible in a
naive text window").

**3. Non-Flutter atom must be const (nit).** A resolved-but-not-Flutter
identifier previously matched by name alone, so a mutable top-level
`bool kDebugMode = true;` or `static bool kDebugMode` field would count as
a guard even though reassignment makes it meaningless as one.

**Fix:** `_isBuildModeConstant`'s non-Flutter branch now additionally
requires the resolved element to be a top-level `const` (unwrapping a
synthetic variable-induced `PropertyAccessorElement` to its underlying
`TopLevelVariableElement` via `isOriginVariable`/`.variable`, the same
pattern `mutable_tearoff_rules.dart`'s `_isMutableReceiver` uses) —
still accepting an UNRESOLVED name by itself, which is what lets this
package's own non-Flutter example fixtures and resolved-rule-harness
tests (which mock these constants as local top-level `const`s) keep
working.

**Files changed (this amendment):**
- `lib/src/rules/security/security_network_input_rules.dart` —
  `_isBuildModeConstant` rewritten (accepts `src/foundation/*`; requires
  `isConst` on a resolved non-Flutter top-level variable); `_findLocalDeclaration`
  simplified to `final`/`const`-only, dropping its `useOffset` parameter;
  removed `_reassignedBetween` and `_DebugGuardReassignmentVisitor`
  entirely (dead code after the simplification).
- `test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart`
  — added the fake-Flutter-package harness (`_runRuleResolvedWithFakeFlutter`,
  `_FakeFlutterRuleContext`) and three new groups: "real Flutter foundation
  import" (4 tests: `kDebugMode`, `!kReleaseMode`, namespaced
  `foundation.kDebugMode`, and an unguarded control, all resolved against
  the fake real-shaped Flutter package), "mutable locals never trusted"
  (2 tests: loop-carried reassignment, and a never-reassigned mutable
  local — both must still fire), and "non-Flutter atom must be const"
  (3 tests: mutable top-level variable, mutable static field, and a
  `const` control that must still suppress).
- No fixture changes this round (the example package's own `_bad11`/
  `_bad12` mutable-local cases from V3 already used `var`/typed mutable
  locals, which now simply never trace at all rather than tracing-then-
  detecting-reassignment — same "still fires" outcome, no edit needed).

**Tests (V4, foreground):**
- `dart analyze` on the 3 touched files → No issues found.
- `dart test test/rules/security/avoid_stack_trace_in_production_debug_guard_test.dart test/rules/security/security_rules_test.dart`
  → All 158 tests passed (30 in the debug-guard file across 6 groups —
  21 carried over from V2/V3 plus 9 new; 128 in security_rules_test.dart).

**Commits:** none created by this agent (per task constraints — no git
operations performed; the other concurrent session on this file has
stopped).

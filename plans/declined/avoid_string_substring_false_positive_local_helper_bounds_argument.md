# BUG: `avoid_string_substring` — Cannot Recognize a Bounds-Proven Argument From a Local Helper Call

**Status: Closed — WONTFIX (documented scope limit)**

Created: 2026-09-18
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~1237)
Severity: False positive (see "Honesty note" — this is a scope-boundary case, not a broken guard)
Rule version: v3 | Since: v4.1.3 | Updated: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Honesty note (read before triaging)

This is **not** a case of the rule ignoring an existing guard idiom (like the `startsWith`/`indexOf`/regex-`.end` carve-outs it already has, per its own fix history in `plans/history/2026.06/2026.06.10/avoid_string_substring_false_positive_*.md` and `plans/history/2026.09/2026.09.05/avoid_string_substring_false_positive_guarded_by_regex_or_indexof.md`). The rule genuinely **cannot** prove this call safe without inlining the body of a private helper function — that is a real, structural limit of a single-file AST rule, not a bug in an existing check. This report is filed as a **targeted extension of the existing bounds-evidence allowlist** (`_isSafeIndexSource`) to a new, narrowly-scoped case (a call to a private, same-file, zero/single-argument helper), not as "the rule is wrong to flag substring by default." If the maintainer judges that extending interprocedural reasoning is out of scope for this rule's design, the correct resolution is a severity/priority note or a documented `// ignore:` at the site — not a code change — and this report should be closed as WONTFIX with that rationale, not silently dropped.

---

## Summary

`sql.substring(_skipLeadingComments(sql))` is flagged because the substring's `start` argument is a call to a private, same-file helper (`_skipLeadingComments`) whose every return path is provably `0 <= r <= sql.length` — but the rule's safe-argument allowlist (`_isSafeIndexSource`) only recognizes `indexOf`/`lastIndexOf`/`group`/`.start`/`.end`-shaped expressions by name, not an arbitrary local function call, so it falls through to the control-flow guard search, finds no enclosing `if`/`while`/`for` guard (there isn't one — the bound is proven inside the callee, not by a caller-side check), and reports.

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_string_substring'" lib/src/rules/
lib/src/rules/code_quality/code_quality_avoid_rules.dart:1237:    'avoid_string_substring',

$ grep -rn "'avoid_string_substring'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches, confirms the rule is not defined downstream)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:1237` (barrel-exported at `lib/src/rules/all_rules.dart:21`)
**Rule class:** `AvoidSubstringRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
/// Returns i where 0 <= i <= sql.length on every return path.
int _skipLeadingComments(String sql) {
  var i = 0;
  final n = sql.length;
  while (i < n) {
    final c = sql.codeUnitAt(i);
    if (c == 0x20) { i++; continue; }
    break;
  }
  return i; // always in [0, n]
}

void classify(String sql) {
  final head = sql.substring(_skipLeadingComments(sql)); // LINT — but provably in-bounds
}
```

Reduced from `saropa_drift_advisor/lib/src/server/host_statement_capture.dart:190-192`:

```dart
final head = _statementHead
    .firstMatch(sql.substring(_skipLeadingComments(sql)))
    ?.group(1)
    ?.toLowerCase();
```

`_skipLeadingComments` (`host_statement_capture.dart:127-152`) returns `n` (`sql.length`) on every early-return path and an in-range `i` on the whitespace/comment-skip fallthrough — `String.substring(start)` accepts `start == length` (returns `''`), so no `RangeError` is reachable here regardless of input.

**Frequency:** Always with this specific shape — a `substring` argument that is a `MethodInvocation` whose callee is not one of the three hardcoded safe names (`indexOf`/`lastIndexOf`/`group`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic, or an INFO-level "cannot verify" note rather than a WARNING crash claim, given the callee is a private, single-file, provably-bounded helper |
| **Actual** | `[avoid_string_substring] substring() throws RangeError if start or end indices are out of bounds...` reported (WARNING) at `host_statement_capture.dart:191` |

---

## AST Context

```
MethodDeclaration (recordStatement)
  └─ BlockFunctionBody
      └─ VariableDeclarationStatement (head)
          └─ MethodInvocation (?.group(1)?.toLowerCase())
              └─ MethodInvocation (_statementHead.firstMatch(...))
                  └─ MethodInvocation (sql.substring(...))  ← node reported here
                      └─ argumentList: [MethodInvocation (_skipLeadingComments(sql))]
```

---

## Root Cause

`AvoidSubstringRule.runWithReporter` (`code_quality_avoid_rules.dart:1249-1261`) calls `_isGuardedByLengthCheck` (`code_quality_avoid_rules.dart:1277-1337`), which first tries a data-flow shortcut, `_hasOnlySafeIndexArguments` (`code_quality_avoid_rules.dart:1518-1534`):

```dart
static bool _hasOnlySafeIndexArguments(MethodInvocation substringCall) {
  final arguments = substringCall.argumentList.arguments;
  if (arguments.isEmpty) return false;
  for (final arg in arguments) {
    if (_isSafeIndexSource(arg)) continue;
    if (arg is SimpleIdentifier) {
      final Expression? initializer = _findLocalInitializer(arg);
      if (initializer != null && _isSafeIndexSource(initializer)) continue;
    }
    return false;   // <-- taken here: _skipLeadingComments(sql) is neither
  }
  return true;
}
```

`_isSafeIndexSource` (`code_quality_avoid_rules.dart:1543-1560`) only recognizes three method names and two property names:

```dart
static bool _isSafeIndexSource(Expression arg) {
  ...
  if (expr is MethodInvocation) {
    final String name = expr.methodName.name;
    return name == 'indexOf' || name == 'lastIndexOf' || name == 'group';
  }
  if (expr is PropertyAccess) { ... return name == 'start' || name == 'end'; }
  if (expr is PrefixedIdentifier) { ... return name == 'start' || name == 'end'; }
  return false;
}
```

`_skipLeadingComments` matches none of these, so `_hasOnlySafeIndexArguments` returns `false`. Control falls through to the AST-parent walk (`code_quality_avoid_rules.dart:1302-1330`), which looks for an enclosing `IfStatement`/`ConditionalExpression`/`WhileStatement`/`ForStatement`/early-exit `Block` that bounds the receiver or argument. At the actual call site, `sql.substring(...)` sits directly inside a chained `firstMatch(...)` expression with no enclosing conditional at all — the bound is proven *inside the callee's own control flow*, which this rule has no way to inspect from the call site. The walk exhausts the parent chain and returns `false`, so `_isGuardedByLengthCheck` returns `false` and the rule reports.

---

## Suggested Fix

Two options, in order of preference:

1. **Narrow, opt-in extension of `_isSafeIndexSource`:** when `arg` is a `MethodInvocation` whose target is `null` (unqualified — same-class/same-file call) or a `PrefixedIdentifier`/simple call to a **private** (`_`-prefixed), zero-or-one-argument static/top-level function declared in the same compilation unit, and the resolver can locate that function's `FunctionDeclaration`/`MethodDeclaration` body, recursively check whether every `return` expression in that body is one of: a literal `0`, the string-length parameter/receiver's own `.length`, or another already-safe source. This is a bounded, single-hop interprocedural check (not general dataflow) — feasible without a full call graph since it only needs to open one more AST node the rule already has the resolved element for.
2. **If (1) is out of scope for this rule's design:** downgrade severity for this shape specifically — when the argument is an unresolvable local call (fails every existing safe-source and guard check, but the callee is same-file and private), report at INFO instead of WARNING, since the rule cannot substantiate a "will crash" claim as confidently as it can for a literal or unguarded external input.

---

## Fixture Gap

Fixture: `example/lib/code_quality/avoid_string_substring_fixture.dart` (confirmed to exist). Existing fixture already covers `indexOf`/regex/`startsWith`/`isEmpty`/loop-bound guards per the fix history above.

Missing NO-LINT case:
1. **Same-file private helper call as the `start` argument, where the helper provably returns a value in `[0, receiver.length]`** — expect NO lint (this report's exact reproducer), OR document as an intentional non-goal in the rule's dartdoc if the maintainer declines interprocedural reasoning.

---

## Changes Made

Per this report's own "Honesty note" and the "Attempted fix reverted" section
below, neither suggested fix is safely implementable:

- **Option 1** (single-hop interprocedural bounds check) was attempted and
  reverted — it did not fix the actual triggering case (an early return
  inside the helper's loop body) and introduced multiple unsound
  false-negative classes (off-by-one comparators, post-loop writes, loop
  step, etc.). Proving a callee's return value is bounded across arbitrary
  control flow, including early returns inside loops, is a genuine
  data-flow/range-analysis problem, not a single-hop AST/syntax heuristic.
- **Option 2** (downgrade severity to INFO for this specific shape) turned
  out to be architecturally unavailable without a separate, larger change:
  `SaropaDiagnosticReporter.atNode`/`atToken` accept an optional `LintCode`
  parameter, but it is dead code — the native reporting path always uses the
  rule's single, fixed `diagnosticCode` (see
  `lib/src/saropa_lint_rule.dart:3385-3387`). At least one other rule
  (`SvgStringMissingErrorBuilderRule` in
  `lib/src/rules/packages/flutter_svg_rules.dart`) already relies on this
  same now-inert per-call-site override, so fixing it properly means
  extending `SaropaDiagnosticReporter` to honor the passed code — a
  cross-cutting change affecting multiple rules, out of scope for this
  single-rule report.

Resolution applied: documented this as an explicit, intentional scope limit
in `AvoidSubstringRule`'s dartdoc
(`lib/src/rules/code_quality/code_quality_avoid_rules.dart`, above the class
declaration), per this report's own suggested fallback. Sites with a
genuinely bounds-safe same-file helper call should suppress with
`// ignore: avoid_string_substring` at the call site.

---

## Tests Added

None — no rule-logic change was made (see "Changes Made"). The fixture gap
noted above is intentionally left uncovered; the correct fixture entry for
this shape is a `// ignore:`-suppressed example demonstrating the documented
non-goal, not a NO-LINT expectation.

---

## Commits

See the commit adding this closure and the `AvoidSubstringRule` dartdoc note.

---

## Environment

- saropa_lints version: 16.2.1 (resolved; checkout at 16.3.0/HEAD, rule source unchanged)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings came from the `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/server/host_statement_capture.dart:191`, scan report `reports/20260918/20260918_081229_findings.json`

---

## Attempted fix reverted (2026-09-18)

A fix was attempted (extending `_isSafeIndexSource` with a single-hop,
syntax-only interprocedural check, `_isProvablyBoundedHelperCall`) and then
reverted after review found it neither fixed the reported case nor was sound:

1. **Does not fix the report.** The real-world helper this report is reduced
   from (`saropa_drift_advisor/lib/src/server/host_statement_capture.dart:128-155`)
   returns early *inside* the `while` body (`if (nl < 0) return n;`). The
   attempted fix's loop-bound check only recognized a loop that precedes the
   `return` in an enclosing block — a `return` reachable from inside the loop
   body itself was not handled. So `sql.substring(_skipLeadingComments(sql))`
   against the *actual* helper from the triggering project was still flagged;
   only the reduced reproducer (which omits the early return) was fixed. The
   regression test added with the fix used the reduced helper, which is why
   this gap wasn't caught before landing.

2. **Introduces new false negatives (unsound).** The loop-bound recognition
   ignored the comparison operator, the loop step, the initial value, and any
   write to the bound variable after the loop. Each of the following was
   wrongly treated as "provably bounded" by the attempted fix, none of which
   actually are:
   - `while (i <= sql.length) i++; return i;` (off-by-one: `<=` admits
     `i == length + 1`)
   - `while (i < sql.length) i++; i = i + 10; return i;` (post-loop write
     invalidates the bound)
   - a loop stepping by `i += 2` (parity/overshoot not accounted for)
   - a negative initial value for the loop variable
   - the parameter reassigned before `return sql.length`

3. **Callee resolution was by name, not by resolved element.**
   `_findCalleeSignature` looked up the callee by matching `name` against
   top-level declarations (and, separately, methods on an enclosing class),
   never against local functions, and with no guarantee the matched
   declaration is actually the one being called (shadowing, overloading-by-
   scope, etc. are all name-only AST heuristics, not semantic resolution).

**Conclusion:** the report's own "Honesty note" anticipated this outcome —
proving a callee's return value is bounded relative to a specific receiver,
across control flow including early returns inside loops, is a genuine
data-flow/range-analysis problem, not something a single-hop AST/syntax
heuristic can do soundly. A correct fix needs either real data-flow analysis
(tracking the possible value range of the loop variable through every exit
path, including returns inside the loop body) or a proper range/interval
analysis pass; short of that, this report should be closed as **won't-fix**
with a doc note on the rule's scope limits, per the report's own suggested
fallback (option 2 in "Suggested Fix").

All code changes from the attempted fix (`lib/src/rules/code_quality/code_quality_avoid_rules.dart`,
`test/rules/code_quality/avoid_string_substring_guard_test.dart`,
`example/lib/code_quality/avoid_string_substring_fixture.dart`) have been
reverted to their pre-fix state. Status reset to Open.

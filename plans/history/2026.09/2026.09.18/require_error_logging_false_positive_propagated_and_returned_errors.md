# BUG: `require_error_logging` — Does Not Recognize `Error.throwWithStackTrace` as Propagation, or Appends to a Returned Error List as Reporting

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-18
Rule: `require_error_logging`
File: `lib/src/rules/flow/error_handling_rules.dart` (line ~2466); shared helper `lib/src/catch_body_logging_utils.dart` (line ~89)
Severity: False positive (4 findings — 1 rethrow-equivalent, 3 documented per-row error channel)
Rule version: v2 | Since: v2.5.0 | Updated: v4.13.0

---

## Summary

Four catch clauses in `drift_debug_import.dart` are flagged as "caught error is not logged." One (`_importJson`, line 54) rethrows via `return Error.throwWithStackTrace(...)` — a `MethodInvocation`, not a `ThrowExpression`/`RethrowExpression`, so the shared `catchBodyHasLoggingCall` detector's throw/rethrow recognition never triggers, and `Error.throwWithStackTrace` is neither a recognized logging method name nor a recognized logger receiver. The other three (lines 79, 123/131, 448/453) append the caught error to `errors`, a `List<String>` field of `DriftDebugImportResult` that is the class's documented, returned per-row/per-statement failure channel (`POST /api/import` handler surfaces it to the HTTP caller) — functionally a report, but not a call the detector's name/receiver lists recognize.

---

## Attribution Evidence

```bash
$ cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'require_error_logging'" lib/src/rules/
lib/src/rules/flow/error_handling_rules.dart:2486:    'require_error_logging',

$ grep -rn "'require_error_logging'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers below cite HEAD.

**Emitter registration:** `lib/src/rules/flow/error_handling_rules.dart:2486` (`LintCode`)
**Rule class:** `RequireErrorLoggingRule` — defined at `lib/src/rules/flow/error_handling_rules.dart:2466`. Exported via barrel `lib/src/rules/all_rules.dart:63` (`export 'flow/error_handling_rules.dart';`). Registered as a runnable rule via factory at `lib/saropa_lints.dart:837` (`RequireErrorLoggingRule.new,`).
**Shared detector:** `catchBodyHasLoggingCall` — `lib/src/catch_body_logging_utils.dart:89`, invoked from `error_handling_rules.dart:2510`.
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Two independent false-positive shapes, both reduced from `drift_debug_import.dart`:

```dart
// Shape 1: rethrow-equivalent via Error.throwWithStackTrace, no `throw`/`rethrow` keyword
Object _decode(String data) {
  try {
    return jsonDecode(data);
  } on FormatException catch (e, st) {
    // LINT (false positive) — this propagates the error with its original
    // stack trace attached; it is not silently swallowed.
    return Error.throwWithStackTrace(FormatException('Invalid JSON: ${e.message}'), st);
  }
}

// Shape 2: error appended to a field returned to the caller as the
// documented failure-reporting channel
class ImportResult {
  final List<String> errors = <String>[];
}

void importRow(ImportResult result, int i, Object row) {
  try {
    writeQuery(row);
  } on Object catch (e) {
    // LINT (false positive) — `result.errors` IS this processor's error
    // reporting mechanism; `result` is returned to and inspected by the caller.
    result.errors.add('Row $i: $e');
  }
}
```

**Frequency:** Always, for (a) any catch body whose only "handling" is a call to `Error.throwWithStackTrace` not wrapped in an explicit `throw`/used via `rethrow`, and (b) any catch body that appends to a collection field the enclosing type documents as its returned failure channel.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on either shape: shape 1 propagates the error (with trace) to the caller; shape 2 reports the error via the function's documented return-value channel. |
| **Actual** | `[require_error_logging] Caught error is not logged to any logging framework or crash reporting service. ...` fires on all four sites: `drift_debug_import.dart:54` (shape 1), and `:79`, `:123/131`, `:448/453` (shape 2). |

---

## AST Context

Shape 1 (`drift_debug_import.dart:53-58`):

```
CatchClause (on FormatException catch (e, st))
  └─ Block
      └─ ReturnStatement
          └─ MethodInvocation (Error.throwWithStackTrace(FormatException(...), st))
              ← visited by _LoggingCallVisitor.visitMethodInvocation;
                methodName 'throwWithStackTrace' not in catchBodyLoggingMethodNames,
                receiver 'Error' not in catchBodyLoggerReceiverNames → found stays false
```

Shape 2 (`drift_debug_import.dart:78-79`, representative of all three):

```
CatchClause (on Object catch (e))
  └─ Block
      └─ ExpressionStatement
          └─ MethodInvocation (errors.add('Row $i: $e'))
              ← methodName 'add' not in catchBodyLoggingMethodNames,
                receiver 'errors' not in catchBodyLoggerReceiverNames → found stays false
```

---

## Root Cause

`RequireErrorLoggingRule.runWithReporter` (`error_handling_rules.dart:2503-2519`) reports whenever `!catchBodyHasLoggingCall(body)` (line 2510). `catchBodyHasLoggingCall` (`catch_body_logging_utils.dart:89-93`) delegates to `_LoggingCallVisitor` (`catch_body_logging_utils.dart:172-203`), which sets `found = true` only for:

- `MethodInvocation` whose `methodName.name` is in `catchBodyLoggingMethodNames` (`catch_body_logging_utils.dart:19-59` — `log`, `print`, `debugPrint`, `error`, `recordError`, etc.), or whose leftmost target identifier is in `catchBodyLoggerReceiverNames` (`catch_body_logging_utils.dart:64-77` — `logger`, `Crashlytics`, `Sentry`, etc.) (`visitMethodInvocation`, lines 176-190).
- `RethrowExpression` (`visitRethrowExpression`, lines 192-196) — unconditional `found = true`.
- `ThrowExpression` (`visitThrowExpression`, lines 198-202) — unconditional `found = true`.

**Shape 1 root cause:** `return Error.throwWithStackTrace(...)` is a `ReturnStatement` wrapping a `MethodInvocation`, not a `throw`/`rethrow` keyword — there is no `ThrowExpression` or `RethrowExpression` node in this AST shape at all, so `visitThrowExpression`/`visitRethrowExpression` never fire. The visitor falls through to `visitMethodInvocation`: method name `throwWithStackTrace` is absent from `catchBodyLoggingMethodNames`, and receiver `Error` is absent from `catchBodyLoggerReceiverNames`. Neither list, nor any other check in `_LoggingCallVisitor`, recognizes `Error.throwWithStackTrace` as propagation when it is used as an expression (return operand) rather than a `throw` operand.

**Shape 2 root cause:** `errors.add(...)`/`result.errors.add(...)` is a plain `MethodInvocation` with method name `add` and receiver `errors`/`result` — neither is in `catchBodyLoggingMethodNames` or `catchBodyLoggerReceiverNames`. `_LoggingCallVisitor` has no dataflow capability to determine that the receiver is a field later returned from the enclosing function as a documented error-reporting channel; it only performs a two-list name/receiver match against the immediate call shape (`catch_body_logging_utils.dart:176-190`).

---

## Suggested Fix

**For shape 1:** in `_LoggingCallVisitor.visitMethodInvocation` (`catch_body_logging_utils.dart:176-190`), add a check for `Error.throwWithStackTrace` specifically (target `Error`, method `throwWithStackTrace`, declaring library `dart:core`) and set `found = true` — this mirrors the existing unconditional `ThrowExpression`/`RethrowExpression` exemptions and would also benefit `avoid_catching_generic_exception`'s body-inspection exemption, which shares this same utility (see the file's own doc comment, `catch_body_logging_utils.dart:3-8`).

**For shape 2:** add a narrower, opt-in heuristic: when a catch body's only statement(s) are `<expr>.add(...)`/`<expr>[...] = ...`-shaped mutations of an identifier that resolves to a field of the enclosing class, and that field is `List<String>`/`List<Object>`-typed and referenced from a `return`-reachable path of a method on the same class (a same-file, same-class dataflow check — not full-program analysis), treat it as "reported via return value" and suppress. This is a materially harder check than shape 1's fix; if full dataflow tracing is out of scope, an interim option is a documented escape hatch (e.g. recognizing a doc comment above the enclosing class containing a fixed marker phrase, or a project-config allowlist of field names like `errors`/`failures`) rather than leaving no path to compliance for a documented per-row failure channel.

---

## Fixture Gap

Fixture at `example/lib/error_handling/require_error_logging_fixture.dart` (46 lines) covers only: empty-body-adjacent `on TimeoutException {}` with no logging (expect LINT) and with a `debug(...)` call (expect NO lint, via the existing `catchBodyLoggingMethodNames`-recognized helper). It has no case for either shape here. Should add:

1. **`return Error.throwWithStackTrace(newError, caughtStackTrace);` inside a `catch (e, caughtStackTrace)` block** — expect NO lint (shape 1).
2. **`throw Error.throwWithStackTrace(newError, caughtStackTrace);` (with explicit `throw`)** — expect NO lint (already covered by the existing `ThrowExpression` exemption, but worth a regression case adjacent to shape 1 to document the asymmetry between `throw <expr>` and `return <expr>` for the same call).
3. **`someResultField.errors.add('...: $e');` where `errors` is a `List<String>` field returned by the enclosing function** — expect NO lint once the return-value-channel fix lands (document as a known gap / xfail until then, per guide convention for unresolved fixture gaps).

---

## Changes Made

See "Finish Report" below.

---

## Tests Added

See "Finish Report" below.

---

## Commits

_Not committed by the fixing agent — left for the branch owner to review/commit._

---

## Finish Report (2026-09-18)

**Verdict: partially valid.**

- **Shape 1 (`Error.throwWithStackTrace`) — valid false positive, fixed.** The
  shared detector genuinely had no path to recognize
  `return Error.throwWithStackTrace(...)`/bare
  `Error.throwWithStackTrace(...)` as propagation: it's a `MethodInvocation`,
  not a `ThrowExpression`/`RethrowExpression`, and neither `throwWithStackTrace`
  nor `Error` appear in the method/receiver name lists.
- **Shape 2 (append to a returned `List<String>` field) — valid observation,
  but the report's own suggested fix is correctly flagged as out of scope for
  this utility.** `catchBodyHasLoggingCall` operates on a single `Block` with
  no visibility into the enclosing class, its fields, or whether some other
  method later returns/inspects that field. Implementing the report's
  suggested dataflow heuristic (same-class field type + return-reachability
  analysis) inside this single-`Block`-scoped visitor would require a much
  larger architectural change and risks new false negatives (e.g. suppressing
  a genuinely-swallowed catch that happens to touch an unrelated list field
  named `errors`). Left unfixed; documented here as a known gap rather than
  implementing the report's own "interim escape hatch" (doc-comment marker /
  config allowlist), which is a policy decision beyond a single bug fix.

**Root cause (shape 1):** `_LoggingCallVisitor.visitMethodInvocation` in
`lib/src/catch_body_logging_utils.dart` only recognized a `MethodInvocation`
as "reported" via the `catchBodyLoggingMethodNames`/`catchBodyLoggerReceiverNames`
name lists; `Error.throwWithStackTrace` matched neither list and has no
`ThrowExpression`/`RethrowExpression` node when used as a `return` operand or
bare statement (only the `throw Error.throwWithStackTrace(...)` form was
already exempt, via `visitThrowExpression`).

**Fix:** Added an explicit case in `visitMethodInvocation` (in the `else`
branch, after the receiver-name check) that sets `found = true` when
`methodName.name == 'throwWithStackTrace'` and the leftmost target identifier
is `'Error'`. This is a narrow, name-based check consistent with the existing
name/receiver-list approach used throughout this utility (the utility
operates on an unresolved `Block` in its unit tests, so a `staticElement`/
`dart:core`-library check wasn't available without a larger signature change).

**Files changed:**
- `lib/src/catch_body_logging_utils.dart` — `_LoggingCallVisitor.visitMethodInvocation`: added the `Error.throwWithStackTrace` exemption.
- `example/lib/error_handling/require_error_logging_fixture.dart` — added `decodeWithStackTrace` (return-wrapped form, GOOD) and `decodeWithStackTraceThrow` (throw-wrapped form, GOOD) regression fixtures.
- `test/utils/catch_body_logging_utils_test.dart` — added 3 unit tests: return-wrapped `Error.throwWithStackTrace` (now `true`), throw-wrapped `Error.throwWithStackTrace` (now `true`), and a negative case (`myHelper.throwWithStackTrace(...)`, unrelated receiver — stays `false`, guards against over-broad matching on method name alone).

**Tests:**
- `dart test test/utils/catch_body_logging_utils_test.dart` — **12/12 passed** (all pre-existing cases still pass; no regressions in existing true-positive/true-negative coverage).
- `dart analyze lib/src/catch_body_logging_utils.dart example/lib/error_handling/require_error_logging_fixture.dart test/utils/catch_body_logging_utils_test.dart` — no issues.
- `test/rules/flow/error_handling_rules_test.dart` could not be loaded during this fix: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` and `lib/src/rules/platforms/windows_rules.dart` had in-progress syntax errors from other agents editing the same tree concurrently (unrelated to this rule; both files were already modified in the branch's git status before this fix started). Not caused by, or fixable within the scope of, this change.

**Proposed CHANGELOG line:**
`fix: require_error_logging no longer flags catch blocks that propagate via Error.throwWithStackTrace(...) used as a return/bare expression (previously only the explicit throw-wrapped form was recognized)`

---

## Environment

- saropa_lints version: 16.2.1 resolved (findings); 16.3.0 / HEAD (source reviewed for this report — confirmed unchanged for this rule since v16.2.1)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (findings from `saropa_lints scan` CLI / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/drift_debug_import.dart:54, 79, 123/131, 448/453`; scan report `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`

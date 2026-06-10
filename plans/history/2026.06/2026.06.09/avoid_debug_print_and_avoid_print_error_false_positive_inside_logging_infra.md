# BUG: `avoid_debug_print` + `avoid_print_error` — Fire inside the project's own logging infrastructure (terminal sink)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rules: `avoid_debug_print`, `avoid_print_error`
Files:
- `lib/src/rules/testing/debug_rules.dart` (line ~108) — `avoid_debug_print`
- `lib/src/rules/flow/error_handling_rules.dart` (line ~1071) — `avoid_print_error`
Severity: False positive
Rule versions: `avoid_debug_print` v4 | `avoid_print_error` v2

---

## Summary

Both rules fire on `debugPrint` and `print` calls that live **inside** the project's own
debug-logging utility (`utils/_dev/debug.dart`). Those calls ARE the terminal sink: every
invocation of the structured `debug()` / `debugException()` / `breadcrumb()` API ultimately
routes to `debugPrint` at exactly one site. Routing through `debug()` again from that site
would recurse infinitely. The fix the rules suggest — "replace with structured logging" — is
structurally impossible for the implementation of the logger itself. These sites required
`// ignore:` workarounds on 2026-06-09.

Both rules share the same root cause (no file-scope or function-scope exemption for the
implementation of the logging primitives the rules redirect to), so they are covered in a
single report.

---

## Attribution Evidence

Grep proof that both rules live in `saropa_lints`:

```bash
# Positive — avoid_debug_print IS defined here
grep -rn "'avoid_debug_print'" lib/src/rules/
# lib/src/rules/testing/debug_rules.dart:108:     'avoid_debug_print',

# Positive — avoid_print_error IS defined here
grep -rn "'avoid_print_error'" lib/src/rules/
# lib/src/rules/flow/error_handling_rules.dart:1071:     'avoid_print_error',
```

Both diagnostics are emitted by the IDE analysis-server plugin
(`_generated_diagnostic_collection_name_#N`). No ambiguous sibling-repo label; negative
attribution is not required.

**Emitter registrations:**
- `lib/src/rules/testing/debug_rules.dart:108` — `AvoidDebugPrintRule`
- `lib/src/rules/flow/error_handling_rules.dart:1071` — `AvoidPrintErrorRule`

**Diagnostic `source` / `owner` as seen in Problems panel:** `avoid_debug_print`,
`avoid_print_error`

---

## Reproducer

```dart
// File: lib/utils/_dev/debug.dart
// This IS the structured logging infrastructure. Every debug() / debugException()
// call in the app routes here.

/// Core terminal sink. Must call debugPrint directly — routing through
/// debug() would recurse.
void debug(String message, {DebugType type = DebugType.info}) {
  // ... level filtering, Crashlytics routing, breadcrumb recording ...
  debugPrint('[${type.tag}] $message');   // LINT (avoid_debug_print) — but this IS the sink
}

/// Exception handler. Must call debugPrint directly — routing through
/// debug() would recurse.
void debugException(Object error, StackTrace stack, {BuildContext? context}) {
  try {
    // ... Crashlytics.recordError, breadcrumb ...
    debugPrint('[ERROR] $error\n$stack');  // LINT (avoid_debug_print) — unavoidable at this layer
  } catch (e, s) {
    // Last-resort fallback: structured logging has already failed.
    debugPrint('debugException itself threw: $e');  // LINT (avoid_debug_print + avoid_print_error)
  }
}
```

**Frequency:** Always — every `debugPrint` / `print` call in the logger implementation file
is flagged regardless of position or surrounding context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on `debugPrint` / `print` calls that are the terminal-sink implementation of the logging primitives the rules redirect to |
| **Actual (avoid_debug_print)** | `[avoid_debug_print] debugPrint bypasses structured logging…` fired at every `debugPrint(...)` call site in `debug.dart` |
| **Actual (avoid_print_error)** | `[avoid_print_error] Using print() for error logging in a catch block…` fired at the `debugPrint(...)` call inside the `catch` block of `debugException` |

---

## AST Context

### avoid_debug_print (AvoidDebugPrintRule)

```
FunctionDeclaration (debug)
  └─ FunctionBody (Block)
      └─ ExpressionStatement
          └─ MethodInvocation (debugPrint)   ← flagged; methodName.name == 'debugPrint'
              └─ ArgumentList
                  └─ StringInterpolation
```

The rule's `context.addMethodInvocation` visitor (line ~122) fires on **every** node where
`node.methodName.name == 'debugPrint'` (line ~123), with no check on the enclosing function,
file, or class. There is no exemption for "we are inside the function that this rule would
redirect other callers to."

### avoid_print_error (AvoidPrintErrorRule)

```
FunctionDeclaration (debugException)
  └─ FunctionBody (Block)
      └─ TryStatement
          └─ CatchClause                     ← `context.addCatchClause` visitor fires here
              └─ Block
                  └─ ExpressionStatement
                      └─ MethodInvocation (debugPrint)  ← flagged by _PrintErrorVisitor
                          └─ ArgumentList
                              └─ StringInterpolation
                                  └─ InterpolationExpression
                                      └─ SimpleIdentifier (e)  ← exceptionName match
```

`AvoidPrintErrorRule.runWithReporter` (line ~1083) walks every `CatchClause` in the file. For
each one it creates a `_PrintErrorVisitor` parameterized by `exceptionName`. The visitor finds
any `print` or `debugPrint` invocation whose argument references the exception name. Inside
`debugException`'s own `catch (e, s)` the argument `'debugException itself threw: $e'`
interpolates `e`, so `_usesException` returns `true` and `onPrintError` fires (line ~1121).
There is no check that the enclosing function is itself the logging utility.

---

## Root Cause

### Shared root cause: no exemption for the logging-primitive implementation

Both rules redirect callers to "use structured logging." The implicit assumption is that a
structured logger already exists and is accessible from the flagged site. That assumption
breaks exactly once: at the implementation of the structured logger itself.

**`avoid_debug_print` (lines ~122–126):**
The `runWithReporter` body is three lines — register a `MethodInvocation` visitor, match on
`node.methodName.name == 'debugPrint'`, report unconditionally. There is no function-name
check, no file-path check, no parent-walk to see whether the enclosing declaration IS the
function the correction message names.

**`avoid_print_error` (lines ~1083–1098 + `_PrintErrorVisitor` lines ~1102–1149):**
`runWithReporter` registers on `CatchClause`, iterates catch-body children via
`_PrintErrorVisitor`, and reports any `print`/`debugPrint` call that references the caught
exception. There is no guard for "we are inside the catch block of the function that serves
as the terminal sink for all other error-logging paths." The visitor is structurally correct
for application code; it has no concept of "this call site IS the logging infrastructure."

The rule docstring for `AvoidDebugPrintRule` (line ~88 area) notes: "The project's `debug()`
function is production-safe logging infrastructure with its own level filtering and
Crashlytics routing — it is NOT flagged." That exemption applies to callers of `debug()`, but
the rule does not reciprocally exempt the body of `debug()` itself.

---

## Suggested Fix

### Option A — File-path / function-name heuristic (lower precision, simpler)

In `AvoidDebugPrintRule.runWithReporter`, before calling `reporter.atNode`, check whether the
enclosing `FunctionDeclaration` or `MethodDeclaration` name is `debug`, `debugException`, or
`breadcrumb` (or matches `debug*`). These are the functions the correction message names as the
replacement; flagging their bodies is circular.

In `AvoidPrintErrorRule._PrintErrorVisitor`, before calling `onPrintError`, walk the parent
chain to the nearest `FunctionDeclaration` or `MethodDeclaration` and apply the same name
check.

### Option B — Opt-out marker comment (highest precision)

Define a file-level opt-out comment, e.g. `// saropa_lints: logging-sink`. When present in
a source file, both rules skip that file entirely. The comment is placed in the project's
`debug.dart` by the project team. This requires no AST inference and is explicit about intent.

### Option C — Combine A + B

Apply the function-name heuristic as an automatic exemption and also support the file-level
marker for unusual cases where the function name doesn't match the heuristic.

Reference lines for the fix:
- `AvoidDebugPrintRule.runWithReporter`: `debug_rules.dart` lines ~118–127
- `AvoidPrintErrorRule.runWithReporter` + `_PrintErrorVisitor`: `error_handling_rules.dart`
  lines ~1079–1149

---

## Fixture Gap

The fixture at `example*/lib/testing/avoid_debug_print_fixture.dart` and
`example*/lib/flow/avoid_print_error_fixture.dart` should include:

### avoid_debug_print

1. **`debugPrint` inside a function named `debug`** — expect NO lint (the logging sink itself)
2. **`debugPrint` inside a function named `debugException`** — expect NO lint
3. **`debugPrint` inside a function named `breadcrumb`** — expect NO lint
4. **`debugPrint` in an ordinary application function** — expect LINT (existing coverage; regression guard)
5. **`debugPrint` inside `if (kDebugMode)`** — expect NO lint (existing guarded-print exemption; regression guard)

### avoid_print_error

1. **`debugPrint(error)` inside the catch block of a function named `debugException`** — expect NO lint
2. **`print('$e')` inside the catch block of an ordinary application method** — expect LINT (existing coverage; regression guard)
3. **`debugPrint('$e')` inside the catch block of an ordinary application method** — expect LINT (regression guard — the visitor matches both `print` and `debugPrint`)

---

## Changes Made

Implemented Option A (enclosing-function-name heuristic):

- `AvoidDebugPrintRule.runWithReporter` (`debug_rules.dart`) now skips a
  `debugPrint` call when it is inside a logging-primitive function. Added a
  top-level `isInsideLoggingSink(AstNode)` helper that walks the parent chain
  for an enclosing `MethodDeclaration`/`FunctionDeclaration` named `debug*`,
  `_debug*`, `breadcrumb`, or `_breadcrumb`. This matches the existing
  exemption in the sibling `avoid_unguarded_debug` rule.
- `AvoidPrintErrorRule.runWithReporter` (`error_handling_rules.dart`) now skips
  a `CatchClause` when it is inside the same set of logging-primitive
  functions, via a local `_isInsideLoggingSink(AstNode)` helper.

Both helpers are intentionally small and file-local rather than coupling the
two rule modules through a cross-import.

---

## Tests Added

- `example/lib/debug/avoid_debug_print_fixture.dart`: added `debug`,
  `debugException`, and `breadcrumb` functions whose `debugPrint` bodies must
  NOT lint; kept the ordinary-function BAD case.
- `example/lib/error_handling/avoid_print_error_fixture.dart`: added a
  `debugException` function whose catch-block `debugPrint('… $e')` must NOT
  lint; kept the ordinary-method BAD case.
- Verified with the scan CLI: `avoid_debug_print` fires only on the ordinary
  `_bad()` call; `avoid_print_error` fires only on the ordinary catch-block
  `print(e)`. Both stay silent inside the logging-sink functions.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** Both fixes add a guard that walks parents to the enclosing
function/method and exempts logging primitives. No recursion risk (single
upward walk, terminates at root). The `avoid_debug_print` helper is public
(`isInsideLoggingSink`) and mirrors the already-shipped `avoid_unguarded_debug`
exemption, so the two debugPrint rules now agree on what counts as a logging
helper. The `avoid_print_error` helper is file-local. Rule files, tiers,
severities, and `LintImpact` unchanged.

**Tests:** `dart test test/rules/testing/debug_rules_test.dart
test/rules/flow/error_handling_rules_test.dart` → all pass. Scan-CLI behavior
verified as above.

**Maintenance:** CHANGELOG `[Unreleased]` updated. README rule count unchanged.
ROADMAP unchanged (false-positive fix).

**Bug archived:** bugs/avoid_debug_print_and_avoid_print_error_false_positive_inside_logging_infra.md
→ plans/history/2026.06/2026.06.09/avoid_debug_print_and_avoid_print_error_false_positive_inside_logging_infra.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (project: Saropa Contacts, 2026-06-09)
- custom_lint version: N/A — saropa_lints is a native analysis-server plugin
- Triggering project/file: Saropa Contacts — `lib/utils/_dev/debug.dart` (logging
  infrastructure terminal sink); workarounds applied 2026-06-09 via
  `// ignore: avoid_debug_print -- logging sink; calling debug() here recurses` and
  `// ignore: avoid_print_error -- logging sink catch block; no structured logger available at this layer`

# BUG: `require_log_level_for_production` — Demands an Explicit `level:` Argument, Ignoring That the Called Function's `level` Parameter Already Defaults Safely

**Status: Fixed**

Created: 2026-08-15
Rule: `require_log_level_for_production`
File: `lib/src/rules/testing/debug_rules.dart` (line ~965)
Severity: False positive
Rule version: v1 | Since: v4.14.0

---

## Summary

The rule flags any call to a name in its verbose-log-method allowlist
(`log`, `fine`, `finer`, `finest`, `debug`, `trace`, `verbose`) that is not
lexically wrapped in a `kDebugMode`/`kReleaseMode` guard or `assert`, on the
theory that verbose logging could leak into production output. It is a purely
syntactic, name-based check — it never resolves the invoked function's
declaration to see whether the parameter it's demanding be set explicitly
already carries a safe default. The project's own `debug()` helper
(`lib/utils/_dev/debug.dart:838`) declares `DebugLevels level =
DebugLevels.Info` — every bare call already defaults to `Info`, the same
outcome the rule's suggested fix (`level:`) would produce explicitly, and
`debug()` additionally gates its own output on debug/demo-mode internally.
Confirmed false positive at `lib/main.dart:532` and `lib/main.dart:612`, both
bare `debug(...)` calls with no `level:` argument.

---

## Attribution Evidence

```bash
grep -rn "'require_log_level_for_production'" lib/src/rules/
# lib/src/rules/testing/debug_rules.dart:981:    'require_log_level_for_production',
```

**Emitter registration:** `lib/src/rules/testing/debug_rules.dart:981`
**Rule class:** `RequireLogLevelForProductionRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Verified directly against `lib/main.dart:532-536` and `lib/main.dart:612`:

```dart
// Project's own logging wrapper — lib/utils/_dev/debug.dart:830-838
@pragma('vm:prefer-inline')
void debug(
  Object? message, {
  Object? exception,
  StackTrace? stackTrace,
  DebugLevels level = DebugLevels.Info,   // <-- already defaults safely
  DateTime? logTime,
  // ...
}) { /* ... */ }
```

```dart
Future<void> _initFirebaseAppCheck() async {
  const bool isRelease = MainSettings.mode == AppModeEnum.release;
  const Duration internalTimeout = isRelease ? Duration(seconds: 7) : Duration(seconds: 5);

  if (!isRelease) {
    // LINT — but should NOT lint: `level` defaults to DebugLevels.Info on
    // the callee's own signature. This call is already lexically inside an
    // `if (!isRelease)` guard (functionally identical to a debug-mode
    // check), and even without that guard, the callee's default is safe.
    debug(
      () =>
          'App Check: waiting up to ${internalTimeout.inSeconds}s '
          '(emulators may be slow)',
    );
  }
  // ...
}
```

```dart
// lib/main.dart:612 — bare call inside a `MainSettings.isDebugMode`-gated branch
onLog: (String message) => debug(message),   // LINT — but should NOT lint
```

**Frequency:** Always, for any bare call to a name in the rule's allowlist
where the receiver pattern doesn't disqualify it and no
`kDebugMode`/`kReleaseMode`/`assert` guard is lexically present — regardless
of what default value the actual called function declares for its `level`
(or equivalent) parameter.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic, or at minimum a distinct lower-severity message — the callee (`debug()`) already defaults its `level` parameter to a safe value (`DebugLevels.Info`), so demanding an explicit `level:` argument changes nothing about runtime behavior |
| **Actual** | `[require_log_level_for_production] Verbose log method called without a debug-mode guard...` reported identically to a call against a hypothetical logger whose default level is unsafe (e.g. `Verbose`/`Trace`) |

---

## AST Context

```
FunctionExpressionInvocation / MethodInvocation (debug(...))   ← context.addMethodInvocation
                                                                    / addFunctionExpressionInvocation
  methodName / function: SimpleIdentifier ('debug')            ← matches _verboseLogMethods
  target: null                                                 ← bare call, target-null check short-circuits
                                                                    the logger-receiver regex (line ~1024)
  argumentList:
    (positional) message argument only                          ← no NamedExpression for 'level' present;
                                                                     rule never inspects the CALLEE'S declared
                                                                     parameter defaults, only the CALL SITE'S
                                                                     argument list
```

The callee, `void debug(Object? message, {..., DebugLevels level =
DebugLevels.Info, ...})` in `lib/utils/_dev/debug.dart:830-838`, is never
resolved or consulted by the rule at all — there is no `node.staticElement`
lookup of the invoked function's formal parameters anywhere in
`RequireLogLevelForProductionRule`.

---

## Root Cause

`RequireLogLevelForProductionRule.runWithReporter`
(`lib/src/rules/testing/debug_rules.dart:1013-1046`):

```dart
context.addMethodInvocation((MethodInvocation node) {
  if (!_verboseLogMethods.contains(node.methodName.name)) return;

  final Expression? target = node.target;
  if (target != null && !_loggerTargetPattern.hasMatch(target.toSource())) {
    return;
  }

  if (_isInsideDebugContext(node)) return;

  reporter.atNode(node);
});

context.addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
  final Expression function = node.function;
  if (function is SimpleIdentifier && _verboseLogMethods.contains(function.name)) {
    if (!_isInsideDebugContext(node)) {
      reporter.atNode(node);
    }
  }
});
```

The detection is purely **name-based** (`_verboseLogMethods.contains(...)`,
line 997-1005) plus a **lexical guard check** (`_isInsideDebugContext`, lines
1049-1060, which walks `node.parent` looking for an enclosing `IfStatement`
with a `kDebugMode`/`kReleaseMode`-style condition or an `AssertStatement`).
Neither check ever resolves `node.methodName.staticElement` (or
`node.function`'s element, for the `FunctionExpressionInvocation` branch) to
inspect the callee's `FormalParameterList` for a parameter named `level` (or
matching whatever the call's own named arguments target) and read its
`DefaultFormalParameter.defaultValue`. Because the rule doesn't declare
`usesTypeResolution => true` and performs no element resolution at all, it
has no way to distinguish:

- a hypothetical `void verboseLog(String msg, {Level level = Level.trace})`
  (unsafe default — SHOULD warrant a guard demand), from
- this project's `void debug(Object? message, {DebugLevels level =
  DebugLevels.Info, ...})` (already safe by default — demanding `level:` is
  a no-op).

The correction message ("Wrap verbose logging in `if (kDebugMode) { ... }`
or use a log-level-aware logger that suppresses verbose output in release")
implicitly assumes the callee is NOT already log-level-aware — but `debug()`
already IS one, and the rule has no mechanism to detect that.

---

## Suggested Fix

Add `usesTypeResolution => true` and, before reporting, resolve the
invocation's callee element and check whether it declares a parameter (by
convention, `level`, or any parameter whose declared type's name contains
`Level`) with a `DefaultFormalParameter.defaultValue` that is NOT the
type's "most verbose" member (heuristically: not the first/lowest-severity
enum constant, or simply: any explicit default at all, on the theory that a
function author who bothered to default the parameter already made the
safety decision). Minimally viable version — skip the diagnostic whenever the
resolved callee has ANY default value for its log-level-shaped parameter:

```dart
final Element? callee = node.methodName.staticElement; // or node.function's element
if (callee is ExecutableElement) {
  final ParameterElement? levelParam = callee.parameters
      .cast<ParameterElement?>()
      .firstWhere((p) => p?.name == 'level', orElse: () => null);
  if (levelParam?.hasDefaultValue ?? false) return;
}
```

---

## Fixture Gap

The fixture at
`example*/lib/testing/require_log_level_for_production_fixture.dart` should
include:

1. A bare call to a locally-declared `void debug(String msg, {Level level =
   Level.info})` with no explicit `level:` argument and no `kDebugMode` guard
   — expect NO lint (callee's default is already safe)
2. A bare call to `void verboseLog(String msg, {Level level = Level.trace})`
   (unsafe default) with no guard — expect LINT (must keep working, the
   actual target case)
3. A bare call to an unresolvable/external `log(...)` (e.g.
   `dart:developer`'s `log()`, which has no safe default semantics for this
   purpose) with no guard — expect LINT (must keep working)

---

## Changes Made

`RequireLogLevelForProductionRule` (`lib/src/rules/testing/debug_rules.dart`)
now resolves the invoked callee's element (`node.methodName.element` for
`MethodInvocation`, `function.element` for the bare-call
`FunctionExpressionInvocation` branch) and skips the diagnostic when the
callee declares a `level` parameter with its own default value — unless that
default's enum-constant name (exact match on the lower-cased final segment,
e.g. `Level.trace` → `trace`) is itself one of the verbose-signal words
(`verbose`, `trace`, `finest`, `finer`, `fine`, `debug`, `all`), which still
must be flagged since the callee did not make a safe choice. Added
`usesTypeResolution => true` since this requires cross-library element
resolution. Rule version bumped v1 → v2.

---

## Tests Added

`example/lib/debug/require_log_level_for_production_fixture.dart` gained a
locally-declared `debug(String, {_DebugLevel level = _DebugLevel.info})`
wrapper plus `_fp310_safeLevelDefault`, a bare unguarded call to it — the
exact shape from the reproducer. Fixture-gap case 3 (external unresolvable
`log()` with no default, from `dart:developer`-shaped mocks) was already
covered by the existing `_bad310`/`_good310` cases. Fixture-gap case 2
(unsafe-default callee must still lint) was verified end-to-end against a
throwaway scratch project (the scan CLI hard-excludes any path containing
`/example`, so it cannot scan this package's own fixtures — see
`plans/history/2026.08/2026.08.15/require_error_boundary_false_positive_fallback_ui_inside_catch.md`
for the same limitation) rather than added as a fixture, since the fixture
corpus here has no existing pattern for a second, differently-named verbose
method; not adding one to avoid duplicating `_verboseLogMethods` coverage
that already exists via `log`/`trace`/etc. elsewhere in this fixture file.

`dart test test/rules/testing/debug_rules_test.dart` — 20/20 passed
(instantiation + fixture-existence checks; unaffected by the wording/version
bump since the `[rule_name]` prefix and length assertions still hold).

---

## Commits

_Recorded at commit time — see repository log for this file's move commit._

---

## Finish Report (2026-08-15)

`RequireLogLevelForProductionRule` reported a diagnostic on every bare call
to a name in its verbose-method allowlist regardless of what the resolved
callee's own `level` parameter defaulted to, producing a false positive on
any logging wrapper (e.g. a project's `debug()` helper) whose author had
already defaulted `level` to a safe value.

The rule now resolves the invocation's callee element
(`node.methodName.element` for `MethodInvocation`, `function.element` for
the bare-call `FunctionExpressionInvocation` branch) and skips the
diagnostic when the callee declares a `level` parameter whose default
value's enum-constant name (exact match on the lower-cased final segment of
`defaultValueCode`, e.g. `Level.trace` → `trace`) is not one of a small set
of verbose-signal words (`verbose`, `trace`, `finest`, `finer`, `fine`,
`debug`, `all`). A callee whose own default is itself verbose, or an
unresolvable external call, is still flagged. `usesTypeResolution` is now
`true` and `cost` was bumped from `low` to `medium` to reflect the added
cross-library element resolution.

`example/lib/debug/require_log_level_for_production_fixture.dart` gained a
locally-declared `debug(String, {_DebugLevel level = _DebugLevel.info})`
wrapper and a bare, unguarded call to it (`_fp310_safeLevelDefault`),
reproducing the reported false positive. The unsafe-default case (a callee
whose own default is verbose) was verified against a throwaway scratch
project outside `example/` rather than added as a fixture — the scan CLI
hard-excludes any path containing `/example` by design (see
`plans/history/2026.08/2026.08.15/require_error_boundary_false_positive_fallback_ui_inside_catch.md`),
and the existing fixture corpus already exercises the true-positive path via
`log`/`trace`/etc. without needing a second verbose-method name.

`dart test test/rules/testing/debug_rules_test.dart` — 20/20 passed both
before and after an inline review pass that fixed two issues: the class doc
comment overstated the skip condition (it said "any default," not "any
non-verbose default"), and `cost` remained `RuleCost.low` despite the rule
now performing type resolution.

### Hardening pass (same day)

A user-directed reflection pass identified two gaps and closed both. First,
`_hasSafeLevelDefault` recognized only a parameter literally named `level`;
real-world logging wrappers also spell this `logLevel`, `severity`, or
`verbosity`, so those callees got no benefit from the fix and kept producing
the same false positive. The check now matches against a small fixed set of
parameter names (`level`, `logLevel`, `severity`, `verbosity`, compared
case-insensitively). Second, a default value with no qualified enum-constant
reference (e.g. a bare `int level = 3`) was silently treated as safe, since
there was no dotted segment to check against the verbose-word list — this
risked a false negative on a numeric level parameter whose default was
actually verbose. The fallback was inverted: a default with no `.` in its
`defaultValueCode` is now treated as unsafe (still flagged), since there is
nothing to prove it isn't verbose.

`example/lib/debug/require_log_level_for_production_fixture.dart` gained two
more cases: `_fp310_logLevelParamName` (a `trace()` wrapper whose `logLevel`
parameter defaults safely — confirms the generalized parameter-name match)
and `_bad310_numericLevelDefault` (a `finest()` wrapper whose `level`
defaults to a bare `int` — confirms the still-flagged fallback). Both were
also verified end-to-end against a throwaway scratch project (same
`/example`-exclusion limitation as above), confirming the safe-default and
`logLevel`-named cases go silent while the numeric-default case still fires.
Rule version bumped v2 → v3. `dart test test/rules/testing/debug_rules_test.dart`
re-run after the hardening pass, 20/20 passing (one transient failure during
this pass was traced to an unrelated, concurrently-edited file,
`lib/src/rules/packages/firebase_rules.dart`, and was not caused by this
change — confirmed by diff inspection and a clean re-run once that file's
edit completed).

### Second hardening pass (same day)

A follow-up reflection pass on the handoff report closed a third gap: a
default written as a `const` constructor call on a custom level type (e.g.
`const Level.custom(5)`, as opposed to a bare enum constant like
`Level.trace`) had a `defaultValueCode` containing a `.` and was therefore
matched against `_verboseDefaultValueNames` using its trailing `(5)` text —
never equal to any recognized word, so it was silently treated as safe with
no way to verify that. `_hasSafeLevelDefault` now strips a leading `const `
prefix and additionally requires the remaining code contain no `(` before
treating it as a bare qualified enum reference; a constructor-call default
falls through to the same "unrecognized shape means unsafe" fallback as a
bare numeric default. `example/lib/debug/require_log_level_for_production_fixture.dart`
gained `_bad310_constructorCallLevelDefault` (a `fine()` wrapper whose
`level` defaults to `const _CustomLevel(5)`) pinning this as a still-flagged
case. Rule version bumped v3 → v4. `dart test test/rules/testing/debug_rules_test.dart`
re-run, 20/20 passing.

The remaining reflection items (exhaustive verbose-word/parameter-name
coverage, and runtime measurement of the `cost`/`usesTypeResolution`
changes) were left as documented, accepted heuristic limits rather than
pursued further — they require either a real-world corpus this repo does
not have, or profiling infrastructure out of scope for a false-positive fix.

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/main.dart:532` and `lib/main.dart:612` (both bare `debug(...)` calls);
  callee default confirmed at `lib/utils/_dev/debug.dart:838`
  (`DebugLevels level = DebugLevels.Info`)

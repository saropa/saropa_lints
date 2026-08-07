# Bug: undefined_identifier `ruleContext` in SaropaLintRule.registerNodeProcessors

**Status:** Fixed
**Severity:** Error (flagged by dart analyze)
**File:** lib/src/saropa_lint_rule.dart:3017

## Description

`registerNodeProcessors` passes `ruleContext: ruleContext` to `SaropaDiagnosticReporter`,
but the method parameter is named `context` (type `RuleContext`), not `ruleContext`.

```dart
void registerNodeProcessors(
  RuleVisitorRegistry registry,
  RuleContext context,        // <-- parameter is `context`
) {
  ...
  final reporter = SaropaDiagnosticReporter(
    this,
    code.lowerCaseName,
    impact: impact,
    lintCode: _lintCode,
    ruleContext: ruleContext,  // <-- should be `context`
  );
```

## Why tests pass

The `registerNodeProcessors` method is only called by the analysis server when
loading the plugin at runtime. `dart test` compiles the code but this code path
is never exercised during testing.

## Impact

The reporter's `_ruleContext` field would be uninitialized or null at runtime,
which could cause `_isIgnoredForFile()`, `_isDuplicateAttempt()`, and
`_resolveLocation()` to fail — all of which read `_ruleContext.currentUnit`.

## Fix

Change line 3017 from `ruleContext: ruleContext` to `ruleContext: context`.

## Found during

recommended.yaml lint cleanup — `dart analyze lib/` with
`include: package:lints/recommended.yaml` (2026-08-06).

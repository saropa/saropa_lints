REF: https://github.com/saropa/saropa_lints/issues/269

# BUG: `infra` — Baseline generator reports false success when analyzer plugin crashes

**Status: Fixed**

Created: 2026-07-01
Rule: N/A (Infrastructure / CLI Tooling)
File: `lib/src/baseline.dart` (or the baseline command entry point)
Severity: High
Rule version: v14.3.0 | Since: Unknown | Updated: v14.3.0

---

## Summary

When running `fvm dart run saropa_lints:baseline`, if the underlying Dart Analysis Server encounters a fatal compilation crash due to a plugin conflict, the tool swallows the error. Instead of exiting with a failure code, it mistakenly prints a success message claiming zero violations were found and no baseline is needed.

---

## Attribution Evidence

The output containing the error and the false success string explicitly names the baseline generator tool belonging to this repository.

```bash
# Command executed
fvm dart run saropa_lints:baseline
```

**Emitter registration:** CLI entry point for baseline generation.
**Diagnostic `source` / `owner` as seen in Problems panel:** N/A (CLI Tool Error)

---

## Reproducer

This issue triggers when running the baseline generator on a project configured with an analyzer plugin that implements Dart's newer native assets/build hooks (`hook/build.dart`), which causes `dart compile` to fail inside the analysis server's plugin manager.

```text
Saropa Lints Baseline Generator
Running lint analysis...
Warning: dart analyze returned errors:

An error occurred while executing an analyzer plugin: Failed to compile 
"C:\Users\EDY\AppData\Local.dartServer.plugin_manager\42bbdc2c26cf3f79118e2baf81c6bdf9\bin\plugin.dart"
 to an AOT snapshot.

stderr = 'dart compile' does not support build hooks, use 'dart build' instead.
#0      PluginManager._compileAsAot (package:analysis_server/src/plugin/plugin_manager.dart:515)
...
No violations found!
Your codebase is already clean - no baseline needed.
```

**Frequency:** Always, when analyzing a codebase that relies on analyzer plugins using native build hooks.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | The tool detects the `exitCode = 255` or the compiler error stream, halts execution, and reports that lint analysis failed to complete. |
| **Actual** | The tool prints the stack trace but appends `No violations found! Your codebase is already clean - no baseline needed.` and exits cleanly. |

---

## AST Context

N/A — This is an infrastructure/runner level bug, not an individual lint rule AST traversal issue.

---

## Root Cause

The baseline runner execution logic doesn't properly validate the success state of the underlying analyzer process. When the plugin manager throws an unhandled exception (`exitCode = 255`), the analyzer halts prematurely and returns an empty or invalid dataset. The baseline tool interprets this empty result set as a perfectly clean codebase instead of an execution failure.

---

## Suggested Fix

Update the baseline generation script to explicitly check the exit codes and `stderr` streams of the runner process. If `dart analyze` or the inner analysis server processes yield an error state or an exit code other than `0`, the script must abort immediately, surface the diagnostic failure to the user, and exit with a non-zero code.

---

## Fixture Gap

The baseline integration tests need an execution test case where the underlying analysis runner fails or mocks an exit code 255 to ensure the command line tool handles process crashes gracefully.

---

## Environment

- saropa_lints version: 14.3.0
- Dart SDK version: 3.x (with native assets preview enabled)
- Triggering project/file: Project using third-party analyzer plugins with `hook/build.dart`

---

## Resolution (2026-07-02)

While verifying the crash fix, a second, deeper defect surfaced that produced
the **same** false "zero violations" symptom on *every* project, not just
crashed ones:

- **Wrong parser (primary everyday cause).** `bin/baseline.dart` ran
  `dart analyze` — whose diagnostics use the hyphen format
  (`info - file:line:col - msg - code`) — but parsed the output with
  `parseViolations`, which only matches the bullet format
  (`file:line:col • msg • code •`) used by the `custom_lint` / `scan` CLIs.
  Verified empirically: on real `dart analyze` output the bullet parser
  returns 0 rows while `parseDartAnalyzeHumanOutput` correctly returns the
  violations. The tool therefore reported *every* project as clean and wrote an
  empty baseline. Fixed by switching the call to `parseDartAnalyzeHumanOutput`.
  End-to-end check: a project with an unused-variable warning now reports
  "Found 1 violation(s)"; a clean project still reports clean.

Both defects are now fixed. The crash-detection change:

`bin/baseline.dart` now validates the analyzer's execution state before
interpreting an empty violation set as a clean codebase.

- **New pure detector:** `lib/src/baseline/analysis_failure.dart` →
  `detectAnalysisFailure(...)`. Returns a failure reason (else `null`) from two
  independent checks: (1) a known fatal analyzer signature in stdout/stderr
  (plugin execution error, AOT-compile failure, "does not support build
  hooks"), matched case-insensitively; (2) a non-zero exit code paired with
  zero parsed violations — a run that neither exited clean (0) nor produced any
  parseable output never completed.
- **Runner change:** on failure the baseline command prints the diagnostic to
  stderr, generates no baseline, and sets `exitCode = 1`. Only when analysis is
  confirmed complete does an empty result print "no baseline needed".
- **Test:** `test/baseline/analysis_failure_test.dart` covers the issue #269
  reproducer (exit 255 plugin AOT crash), signature match at exit 0, non-zero +
  empty, genuine clean (exit 0, no violations → null), and the normal
  violations-parsed case (non-zero exit → null).

---

## Finish Report (2026-07-02)

### Defect

The `saropa_lints:baseline` CLI reported a false "clean codebase — no baseline
needed" success (exit 0) under two independent conditions, both surfacing the
same symptom of zero detected violations.

### Root causes and fixes

1. **Wrong diagnostic parser (everyday cause, all projects).** The command runs
   `dart analyze`, which emits the hyphen diagnostic format
   (`severity - file:line:col - message - code`), but `bin/baseline.dart`
   parsed with `parseViolations`, which only matches the mutually-exclusive
   bullet format (`file:line:col • message • code •`) produced by the
   `custom_lint` / `scan` CLIs. On real `dart analyze` output the bullet parser
   returns zero rows, so every project was reported clean and an empty baseline
   was written. Fixed by calling `parseDartAnalyzeHumanOutput`, the existing
   matcher for `dart analyze` output. Verified empirically: bullet parser → 0
   rows, hyphen parser → correct violations, on identical real output.

2. **Swallowed analyzer crash (issue #269).** When the analysis server crashed
   (an analyzer plugin failing to AOT-compile, exit 255), the runner emitted no
   parseable violations and interpreted the empty result as clean. A new pure
   helper, `detectAnalysisFailure` in `lib/src/baseline/analysis_failure.dart`,
   distinguishes a crash from a genuinely clean run by inspecting the process
   exit state and output: it returns a failure reason when a known fatal
   analyzer signature appears (case-insensitive) or when a non-zero exit is
   paired with zero parsed violations, and `null` otherwise. On failure the
   runner prints the diagnostic to stderr, writes no baseline, and sets
   `exitCode = 1`; a clean run (exit 0, no violations) still reports "no
   baseline needed".

### Interaction between the two fixes

The parser fix is a prerequisite for the crash heuristic's soundness: with the
correct parser, a project with real warnings/errors (exit 2/3) parses to a
non-zero count and is not misread as a failed run; only a true crash yields the
non-zero-exit-with-empty-output state the heuristic flags.

### Verification

- Unit: `test/baseline/analysis_failure_test.dart` — 6 cases (crash exit 255,
  signature at exit 0, generic non-zero + empty, clean exit-0-empty → null,
  real-violations non-zero → null, case-insensitive match). Full run: 29/29
  pass alongside the existing `violation_parser` suite.
- End-to-end: a temporary project with an unused-variable warning now reports
  "Found 1 violation(s)"; a clean project reports clean with exit 0. The `bin`
  wiring itself has no automated end-to-end test (pre-existing coverage gap).

### Related, unaddressed

`bin/severity_report.dart` runs `dart analyze` and parses with the same
incorrect `parseViolations`, so it always reports zero issues. Same defect
class, separate file, out of scope for this bug; left untouched pending a
decision.

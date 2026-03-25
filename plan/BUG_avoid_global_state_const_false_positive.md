# BUG: avoid_global_state flags `const` declarations as mutable global state

**Rule**: `avoid_global_state`
**Severity**: False positive (suspected)
**Date**: 2026-03-25
**Status**: Needs reproduction
**Related**: [BUG_avoid_global_state_static_class_fields.md](BUG_avoid_global_state_static_class_fields.md)

## Summary

The rule reportedly fires on `const` top-level declarations in a consumer project file. However, code review of the guard logic confirms it is correct — `const` and `final` declarations are properly skipped. This is most likely a stale analysis cache artifact rather than a code bug.

## Affected File

`lib/utils/_dev/debug.dart` (consumer project, not in this repo)

## Violations Reported

| Reported Line | Actual Code at That Line | Actual Variable (Next Line) |
|---|---|---|
| L30 | `/// was broken in https://dartcode.org/releases/v3-98/` (doc comment) | L31: `const bool _isColorLineOutput = true;` |
| L33 | `/// Default number of stack frames to display in debug logs` (doc comment) | L34: `const int kDefaultStackFrameCount = 6;` |

## Analysis

The file has exactly **three** top-level variable declarations:

1. `const bool _isColorLineOutput = true;` (L31) — **const**
2. `const int kDefaultStackFrameCount = 6;` (L34) — **const**
3. `final DebugLogSuppressor _logSuppressor = DebugLogSuppressor();` (L108) — **final**

All three are either `const` or `final`. The rule's guard logic at `structure_rules.dart:468`:

```dart
if (variables.isConst || variables.isFinal) continue;
```

...should skip all of them. `VariableDeclarationList.isConst` returns `true` when the `const` keyword is present, and `isFinal` returns `true` for `final`. This guard is provably correct for these declaration patterns.

### Why this is likely NOT a code bug

The `reporter.atNode(variable)` call at line 472 is **unreachable** for const/final variables — the `continue` at line 468 skips the entire inner loop. A line-offset bug in the reporter cannot create violations that the guard prevents from being reported in the first place.

The `SaropaDiagnosticReporter.atNode()` method does have `AnnotatedNode` handling that adjusts offsets via `firstTokenAfterCommentAndMetadata`, but this code path is never reached for const/final declarations.

## Root Cause Assessment

| # | Cause | Likelihood | Reasoning |
|---|-------|-----------|-----------|
| 1 | **Stale analysis cache** | **High** | Violations computed against an older file version where these were `var` or `late`, and results weren't invalidated. |
| 2 | **Misattributed violations** | **Medium** | The companion bug report documents violations appearing at wrong line numbers. If `_logSuppressor` was previously mutable (`var` or `late`), its violation could appear at L30/L33 due to a line-mapping bug. |
| 3 | **`isConst` check failing** | **Very low** | `VariableDeclarationList.isConst` is a fundamental Dart analyzer API. It would have to be broken for millions of users to affect these simple patterns. |

## Reproduction Needed

The original report did not specify whether a fresh analysis (analyzer restart) was performed. To confirm or rule out this bug:

1. **Restart the analyzer server** in the consumer project (VS Code: "Dart: Restart Analysis Server")
2. Check if the violations persist on the current file contents
3. If they disappear, this was a stale cache issue — close as not-a-bug

If violations persist after restart, add a targeted test case:

```dart
// example_core/lib/structure/avoid_global_state_fixture.dart (extend existing)

/// Doc comment for const variable
const bool _isColorLineOutput = true; // OK: const

/// Another doc comment
const int kDefaultStackFrameCount = 6; // OK: const

/// Final variable
final String defaultName = 'test'; // OK: final

var mutableCount = 0; // LINT: mutable top-level variable
```

## Existing Test Gap

The current unit tests for `avoid_global_state` are **stubs** that always pass:

```dart
test('avoid_global_state SHOULD trigger', () {
  expect('avoid_global_state detected', isNotNull); // always true
});
```

Real assertions against parsed code are needed to validate the guard logic. This should be addressed regardless of whether this specific bug is confirmed.

## Suggested Actions

1. **Attempt reproduction** with a fresh analyzer restart in the consumer project.
2. **Add real unit tests** for the rule covering:
   - `const` top-level variables (should NOT trigger)
   - `final` top-level variables (should NOT trigger)
   - `var` / `late` top-level variables (SHOULD trigger)
   - Variables preceded by doc comments (should not affect detection)
3. **Cross-reference** the companion bug's wrong-line-number findings — if that bug is confirmed, the reported line offsets here may have the same root cause.

# BUG: `prefer_debug_print` — Fires on pure Dart packages that cannot import Flutter

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-21
Rule: `prefer_debug_print`
File: `lib/src/rules/testing/debug_rules.dart` (line ~509)
Severity: False positive
Rule version: v1 | Since: unknown | Updated: (unchanged since introduction)

---

## Summary

`prefer_debug_print` tells the author to replace `print()` with `debugPrint()`, but `debugPrint()` lives in `package:flutter/foundation.dart`. Pure Dart packages (no Flutter dependency) cannot satisfy the rule without adding Flutter as a runtime dependency, which is a non-trivial ask and often explicitly forbidden. The rule should skip non-Flutter projects the same way `avoid_print_in_release` already does in the same file.

---

## Reproducer

Real-world trigger: `saropa_drift_advisor` 3.3.3 (`pubspec.yaml` declares `environment: sdk: ">=3.9.0 <4.0.0"` and has **zero** runtime dependencies by design). Five sites fire:

- `lib/src/error_logger.dart:69` — banner echo inside log callback
- `lib/src/error_logger.dart:117` — error echo inside error callback
- `lib/src/error_logger.dart:120` — stack trace echo inside error callback
- `lib/src/drift_debug_server_io.dart:224` — server startup banner
- `lib/src/drift_debug_server_io.dart:238` — server startup failure

Minimal reproducer (a pure Dart library, no Flutter dependency):

```dart
// pubspec.yaml has NO `flutter:` section and does NOT depend on flutter.
// dependencies: {}  // zero runtime deps

void logLine(String line) {
  // ignore: avoid_print
  print(line); // LINT — but should NOT lint (false positive)
  // debugPrint is not in scope: adding `package:flutter/foundation.dart`
  // would require a Flutter dependency, which this package does not take.
}
```

**Frequency:** Always, on any `print()` call in a pure Dart package regardless of whether Flutter is importable.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the containing project is not a Flutter project (`ProjectContext.isFlutterProject == false`). |
| **Actual** | `[prefer_debug_print] print() should use debugPrint() for throttled console output. {v1}` fires on every top-level `print(...)` call. |

---

## AST Context

```
CompilationUnit (pure Dart library)
  └─ FunctionDeclaration (logLine)
      └─ BlockFunctionBody
          └─ Block
              └─ ExpressionStatement
                  └─ MethodInvocation (print)   ← node reported here
```

Nothing in the AST reveals that `debugPrint` is unreachable — that information is only available from the project's pubspec/imports.

---

## Root Cause

### Hypothesis A: Missing Flutter-project guard (primary)

`PreferDebugPrintRule.runWithReporter` at `lib/src/rules/testing/debug_rules.dart:538-566` contains no project-type gate. Compare with the sibling rule `AvoidPrintInReleaseRule.runWithReporter` in the same file at line ~626:

```dart
// avoid_print_in_release — correctly gated
final projectInfo = ProjectContext.getProjectInfo(context.filePath);
if (projectInfo == null || !projectInfo.isFlutterProject) return;
```

`prefer_debug_print` does the opposite — recommends a Flutter-only API without checking whether Flutter is in scope. Since `debugPrint` does not exist in pure Dart, the rule's recommendation is literally unactionable.

### Hypothesis B: Rule should also respect `// ignore: avoid_print` on the same line

Secondary observation: all five sites in the triggering project already carry `// ignore: avoid_print` (and some also `avoid_print_in_release`) with comments explaining why `print()` is required (`developer.log` is invisible in the standard Flutter/IDE console and on Android). A newer rule that asks the author to replace `print()` with `debugPrint()` sidesteps the existing ignore, forcing the author to add a second ignore per site. Less important than Hypothesis A, but worth considering: if `avoid_print` is already ignored, the author has already asserted `print()` is intentional.

---

## Suggested Fix

In `lib/src/rules/testing/debug_rules.dart`, add a guard at the top of `PreferDebugPrintRule.runWithReporter` matching the pattern used by `AvoidPrintInReleaseRule`:

```dart
@override
void runWithReporter(
  SaropaDiagnosticReporter reporter,
  SaropaContext context,
) {
  // debugPrint() lives in package:flutter/foundation.dart. Recommending it
  // in a pure Dart package is unactionable — the author would have to take
  // on a full Flutter dependency just to silence this lint.
  final projectInfo = ProjectContext.getProjectInfo(context.filePath);
  if (projectInfo == null || !projectInfo.isFlutterProject) return;

  context.addMethodInvocation((MethodInvocation node) {
    if (node.methodName.name != 'print') return;
    if (node.target != null) return;
    reporter.atNode(node);
  });

  context.addFunctionExpressionInvocation((
    FunctionExpressionInvocation node,
  ) {
    final Expression function = node.function;
    if (function is SimpleIdentifier && function.name == 'print') {
      reporter.atNode(node);
    }
  });
}
```

Bump the rule version marker `{v1}` → `{v2}` in the `LintCode.problemMessage` and update the `Since:` / `Updated:` doc line.

---

## Fixture Gap

`example/lib/debug/prefer_debug_print_fixture.dart` imports `package:saropa_lints_example/flutter_mocks.dart`, so every existing test case is implicitly "inside a Flutter project". The fixture does not exercise the pure-Dart-package branch.

The fixture (or a sibling fixture in a non-Flutter example package) should include:

1. **Pure Dart file, no Flutter mocks imported, `print()` at top level** — expect NO lint (this is the regressing case).
2. **Flutter file, `print()` at top level** — expect LINT (existing behavior preserved).
3. **Flutter file, `debugPrint()` at top level** — expect NO lint (existing behavior preserved).

The non-Flutter case specifically needs the fixture's `pubspec.yaml` to omit `flutter:` / `sdk: flutter`, because `ProjectContext.getProjectInfo` reads the real pubspec.

---

## Changes Made

Implemented **Hypothesis A** (Flutter-project guard) exactly as described. Hypothesis B (respect `// ignore: avoid_print`) was deliberately NOT implemented — the Flutter-project guard alone fully resolves the reported five call sites, and an `avoid_print` → `prefer_debug_print` ignore-suppression chain would add cross-rule coupling the project does not otherwise have (see [CLAUDE.md](../../../../CLAUDE.md) § "Do not add `// ignore` or `// ignore_for_file`" and the bug's own "Less important than Hypothesis A" caveat).

- [lib/src/rules/testing/debug_rules.dart](../../../../lib/src/rules/testing/debug_rules.dart) — `PreferDebugPrintRule.runWithReporter` now opens with the same `ProjectContext.getProjectInfo(context.filePath)` / `!projectInfo.isFlutterProject → return` guard used by the sibling `AvoidPrintInReleaseRule` ~60 lines below, so the two rules agree on which projects print-related advice is actionable in. `ProjectContext` is already in scope via the transitive `export 'project_context.dart'` in [lib/src/saropa_lint_rule.dart](../../../../lib/src/saropa_lint_rule.dart), so no new import is required.
- `LintCode.problemMessage` version marker bumped `{v1}` → `{v2}`; DartDoc header updated to `Since: unknown | Updated: v12.3.3 | Rule version: v2` and gains a new **Scope** paragraph that documents the Flutter-only gate and its rationale so consumers reading the hover tooltip understand why a pure Dart file does not trigger.
- [example/lib/debug/prefer_debug_print_fixture.dart](../../../../example/lib/debug/prefer_debug_print_fixture.dart) — removed the now-invalid `// expect_lint: prefer_debug_print` marker (`example/pubspec.yaml` has no Flutter dependency, so the gate correctly returns early on every file in that package), replaced with prose comments that document the new behavior, and added a `_pureDartNoLint` function that mirrors the minimal reproducer from this bug report (two unguarded top-level `print(...)` calls that must not lint). The existing BAD / GOOD pair (`_bad309` / `_good309`) is retained as documentation of the recommendation shape for Flutter consumers.
- [CHANGELOG.md](../../../../CHANGELOG.md) — new `### Fixed` bullet under `[Unreleased]` citing the `saropa_drift_advisor` 3.3.3 trigger, the five affected call sites, the version bump, and links to this bug report + the modified source and fixture files.

---

## Tests Added

- [example/lib/debug/prefer_debug_print_fixture.dart](../../../../example/lib/debug/prefer_debug_print_fixture.dart) gains `_pureDartNoLint()` — two `print(...)` calls in a top-level function with no Flutter imports, both annotated `// expect NO lint`. This is the regression guard: if a future refactor drops the `isFlutterProject` gate, `custom_lint` over the example package will start producing `prefer_debug_print` diagnostics on those lines. The existing `_bad309` / `_good309` pair is retained and re-documented so the recommendation shape for Flutter consumers stays visible.
- No new unit test in `test/debug_rules_test.dart` — the existing `PreferDebugPrintRule` instantiation test at [test/debug_rules_test.dart:42](../../../../test/debug_rules_test.dart#L42) continues to assert `rule.code.lowerCaseName == 'prefer_debug_print'` and `problemMessage` contains the `[prefer_debug_print]` prefix, and the fixture-exists probe at [test/debug_rules_test.dart:99](../../../../test/debug_rules_test.dart#L99) still passes. The `prefer_debug_print` cases in the `Debug Rules - Fixture Verification` group at [test/debug_rules_test.dart:186-193](../../../../test/debug_rules_test.dart#L186-L193) are placeholder `expect('...', isNotNull)` assertions (pre-existing pattern across the file); adding real AST-driven assertions there would be a separate pass across all ten rules in the group, out of scope for this bug.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 12.3.3
- Dart SDK version: >=3.9.0 <4.0.0 (triggering project constraint)
- custom_lint version: (whatever ships with saropa_lints 12.3.3)
- Triggering project/file: `saropa_drift_advisor` 3.3.3 — `lib/src/error_logger.dart`, `lib/src/drift_debug_server_io.dart` (pure Dart package, zero runtime dependencies)

# Fix: `avoid_ios_battery_drain_patterns` false positive on disposed UI timers

`AvoidIosBatteryDrainPatternsRule` flagged every short-interval `Timer.periodic` call
as a potential battery drain, including timers scoped to a Flutter `State` subclass
and cancelled in `dispose()` — a UI clock/countdown timer that stops existing with the
widget and cannot drain battery in the background. This forced an `// ignore:`
workaround on a common, benign UI pattern.

Corresponds to bug report `avoid_ios_battery_drain_patterns_false_positive_ui_timer.md`
(filed against this rule; the report file lives outside this change's tree and is not
archived here — see Notes below).

## Root cause

`lib/src/rules/platforms/ios_platform_lifecycle_rules.dart`, class
`AvoidIosBatteryDrainPatternsRule`: the `Timer.periodic` check only inspected the
duration argument for a short interval. It never checked whether the timer was
lifecycle-bound to a widget (created in a `State<T>` subclass, cancelled in
`dispose()`), so every UI-only periodic timer with a sub-5-second interval was
flagged regardless of teardown.

## Fix

Added a private helper, `_isTimerInDisposableState(MethodInvocation node)`, called
before the existing duration check:

1. Walks up from the `Timer.periodic` call to the enclosing `ClassDeclaration`.
2. Confirms the class `extends State` (by name, matching the existing convention
   used elsewhere in the codebase, e.g. `avoid_disposing_late_fields_rules.dart`).
3. Delegates to the existing shared utility `isBackgroundWorkCanceledInDispose`
   (`lib/src/target_matcher_utils.dart`) to confirm the timer's field is
   `.cancel()`'d inside `dispose()`. This is the same utility already used by
   `RequireAppLifecycleHandlingRule` (`lifecycle_rules.dart`) and
   `require_workmanager_for_background`-adjacent disposal rules for the identical
   "torn down alongside the widget" heuristic, so the two rules now agree on what
   counts as lifecycle-managed.

When all three hold, the rule returns early and does not flag the timer. Any class
shape it cannot confirm (no enclosing class, not a `State` subclass, no
`dispose()`/`.cancel()`) falls through unchanged to the existing duration check.

## Detection-path finding (unrelated to the fix logic, but load-bearing for testing it)

`Timer.periodic(...)` is a **factory constructor** in `dart:async`. The rule detects
it via `context.addMethodInvocation` matching `node.methodName.name == 'periodic'`
with a `Timer` target — this only matches while the AST node is still a
`MethodInvocation`. Once an analyzer session fully **resolves** the call (as the
existing `test/support/resolved_rule_harness.dart` oracle does, and as an IDE/analyzer
plugin session normally would), the analyzer rewrites the node to an
`InstanceCreationExpression`, and the rule's `addMethodInvocation` match silently
sees nothing — regardless of the fix under test.

This was discovered while writing this fix's regression tests: an initial attempt
using `resolved_rule_harness.dart` (real `dart:async` `Timer`) produced empty
diagnostics for every case, including cases that should fire. Instrumenting
`SaropaContext._wrapCallback` and `ScanWalker.visitNode` confirmed the node type at
walk time was `InstanceCreationExpressionImpl`, not `MethodInvocationImpl`, once
resolved — even against the project's own `example/lib/flutter_mocks.dart` mock
`Timer` class, since that mock also declares `Timer.periodic` as a genuine named
constructor.

This means the rule, as shipped (both before and after this fix), only ever fires
under a **syntactic** (unresolved) pass — i.e. the default `saropa_lints scan`
behavior ("scan on save"), not a fully resolved analyzer-plugin/IDE pass. That
matches the bug report's own evidence path (a `dart run saropa_lints scan` finding),
and is consistent with the project's documented `--resolve` caveat for
instance-creation-shaped detections.

## New test infrastructure

Added `test/support/syntactic_rule_harness.dart` — a sibling to
`resolved_rule_harness.dart` that runs a rule against `parseString()` output with
**no** type resolution, mirroring `ScanRunner._scanSingleFile` in
`lib/src/scan/scan_runner.dart`. This is the correct oracle for any rule whose
detection depends on a bare `Identifier.identifier(args)` call staying a
`MethodInvocation` (i.e. any rule matching a constructor-shaped call by
`addMethodInvocation` rather than `addInstanceCreationExpression`). The resolved
harness remains correct and necessary for rules that genuinely need type
information; this new harness fills the gap for rules that must NOT be resolved to
be exercised correctly.

## Tests

`test/rules/platforms/avoid_ios_battery_drain_patterns_disposable_state_test.dart`
(new), using the new syntactic harness:

1. `Timer.periodic` in a `State` subclass, cancelled in `dispose()` — asserts no
   `avoid_ios_battery_drain_patterns` diagnostic.
2. `Timer.periodic` in a `State` subclass, NOT cancelled in `dispose()` — asserts the
   diagnostic still fires (the real battery-drain risk the rule exists to catch).
3. `Timer.periodic` in a non-`State` service class — asserts the diagnostic still
   fires regardless of an unrelated `stop()` method calling `.cancel()`, since there
   is no widget lifecycle to lean on.

All three pass. Full regression run of `test/rules/platforms/ios_rules_test.dart`
(182 tests) and `test/rules/platforms/ios_security_quick_fix_presence_test.dart`
(105 tests) also pass, confirming no other iOS rule behavior shifted.

## Notes / limitations

- This change was made from an isolated git worktree that does not contain the
  original bug report file (`bugs/avoid_ios_battery_drain_patterns_false_positive_ui_timer.md`)
  — the file exists, untracked, in the main checkout's working tree, and worktrees
  only see committed content. The mandatory bug-archival step (mark `Fixed`,
  `git mv` to `plans/history/`) could not be performed from this worktree; it
  requires a follow-up action in the main checkout (or a future session with access
  to that file) to mark it `Fixed` and archive it to
  `plans/history/2026.09/2026.09.05/`, pointing at this report.
- No CHANGELOG "Unreleased" section existed at the start of this change (the
  changelog's top section was the just-released `16.0.0-beta.4`); a new
  `## [16.0.0-beta.5] — Unreleased` section was added per the project's documented
  post-release convention, with a `### Fixed` entry for this bug.

# Dead rules from no-op stub registrations

**Status:** In progress
**Found:** 2026-07-16 (during the rule-liveness fixture pass, `plans/TODO_rule_metadata_completeness.md` §4.1)
**Severity:** High — each affected rule produces **no diagnostic for any user**, silently.

## Root cause

The native engine's `SaropaContext` (`lib/src/native/saropa_context.dart`) has three
registration methods that are **no-op stubs** — they accept a callback and discard it
(the callback is never stored and never called). They exist so rules ported from the
retired v4 plugin still compile. Any rule whose detection/reporting depends on one of
these registrations never runs.

```dart
// lib/src/native/saropa_context.dart, "No-op stubs" section
void addPostRunCallback(void Function() callback) {}                 // ~996
void addFunctionBody(void Function(FunctionBody) callback) {}        // ~1002
void addFormalParameter(void Function(FormalParameter) callback) {}  // ~1008
```

These are distinct from the **real** methods with similar names — `addBlockFunctionBody`,
`addExpressionFunctionBody`, `addSimpleFormalParameter`, `addDefaultFormalParameter`,
`addFormalParameterList` — which work. The fix for the first two stub families is to
switch the rule to the correct real method. `addPostRunCallback` has **no drop-in
replacement** (see below).

Why this went unnoticed: nothing errors. The rule compiles, registers "successfully"
(into a no-op), and simply never fires. Rules without fixtures were invisible; rules
with fixtures showed up in the `accuracy_report` silent list mixed among the ordinary
fixture-inadequacy cases.

## `addFunctionBody` — FIXED 2026-07-16

5 call sites, all switched to `addBlockFunctionBody` (each already narrowed the body to
`BlockFunctionBody`). Verified firing; commits on `main`.

- `avoid_sequential_awaits` — `core/async_rules.dart`
- `require_getit_registration_order` — `packages/get_it_rules.dart`
- `require_hive_adapter_registration_order` — `packages/hive_rules.dart`
- `prefer_single_exit_point` — `stylistic/stylistic_control_flow_rules.dart`
- `prefer_guard_clauses` — `stylistic/stylistic_control_flow_rules.dart`

(The last four had no fixtures; permanent fixtures were added.)

## `addFormalParameter` — FIXED 2026-07-16

2 call sites, both switched to `addSimpleFormalParameter` (both only acted on
`SimpleFormalParameter`). Verified firing on their existing fixtures.

- `pass_correct_accepted_type` — `code_quality/code_quality_prefer_rules.dart` (was
  fully dead — its only registration). v4 → v5.
- `prefer_correct_identifier_length` — `core/naming_style_rules.dart` (was partially
  dead — the variable-name branch worked via `addVariableDeclaration`; the
  parameter-name branch was dead). v6 → v7. Field/super/function-typed parameters are
  not length-checked, an acceptable minor gap versus total deadness.

## `addPostRunCallback` — NOT YET FIXED (needs restructuring, not a one-liner)

`addPostRunCallback` is meant to fire *after* the whole file is scanned, so a rule can
aggregate state during the main pass and report at the end (e.g. "this provider forms a
cycle" needs to see every provider first). Because it is a no-op, any `reporter.*` call
inside the callback is dropped. There is **no drop-in replacement**: each rule must be
restructured to report during the main pass, or run a self-managed second pass (the bloc
rule at `packages/bloc_rules.dart:367` already hand-worked around this with a two-pass
approach — a template for the others).

**9 call sites confirmed to call `reporter.*` inside the discarded callback.** Each needs
per-rule restructuring AND a check for whether it also reports elsewhere (fully vs.
partially dead):

| Rule | File:line |
|---|---|
| `require_menu_bar_for_desktop` | `core/performance_rules.dart:3708` |
| `require_window_close_confirmation` | `core/performance_rules.dart:3813` |
| `require_error_state` | `packages/bloc_rules.dart:1180` |
| `avoid_circular_provider_deps` | `packages/riverpod_rules.dart:2574` |
| `prefer_notifier_over_state` | `packages/riverpod_rules.dart:2827` |
| `require_apple_sign_in` | `platforms/ios_ui_security_rules.dart:766` |
| `require_error_case_tests` | `testing/testing_best_practices_rules.dart:2846` |
| `avoid_test_coupling` | `testing/test_rules.dart:1100` |
| `require_test_cleanup` | `testing/test_rules.dart:2700` |

## Follow-up to prevent recurrence

The no-op stubs should fail loudly instead of silently. Options (not yet decided):
- Make `addFunctionBody`/`addFormalParameter` `@Deprecated` so callers get an analyzer
  warning at author time (they still compile, but the warning surfaces the trap).
- Add an integrity test that greps the rules tree for calls to the three stub method
  names and fails, forcing authors to the real methods.
- Have the stubs assert/throw in debug builds so a rule that registers into one is
  caught the first time its fixture is scanned.

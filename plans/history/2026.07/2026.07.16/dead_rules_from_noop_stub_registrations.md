# Dead rules from no-op stub registrations

**Status:** Fixed
**Found:** 2026-07-16 (during the rule-liveness fixture pass, `plans/TODO_rule_metadata_completeness.md` §4.1)
**Severity:** High — each affected rule produced **no diagnostic for any user**, silently.

All three stub families are now clear of live callers, verified by a new integrity
test (`test/integrity/no_op_stub_registration_guard_test.dart`) that fails the
build if any rule calls `addPostRunCallback`, `addFunctionBody`, or
`addFormalParameter`. The full inventory grew from the original 9
`addPostRunCallback` sites to **14** once the whole rules tree was grepped (the
first pass had only sampled part of it).

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

## `addPostRunCallback` — FIXED 2026-07-16

`addPostRunCallback` was meant to fire *after* the whole file is scanned, so a rule can
aggregate state during the main pass and report at the end (e.g. "this provider forms a
cycle" needs to see every provider first). Because it is a no-op, any `reporter.*` call
inside the callback was dropped. There is no drop-in replacement, so each rule was
restructured to gather state in a single `addCompilationUnit` pass and report at its end
(the compilation-unit callback runs synchronously, so a manual `unit.accept(visitor)` —
or the existing `visitChildren` traversal — fully populates the aggregates before the
report loop runs). The bloc rule at `packages/bloc_rules.dart:369`
(`require_immutable_bloc_state`) already used this shape and served as the template.

**Verification (accuracy_report, resolved scan) — all 14 confirmed firing.** Six fire in
the full example/lib corpus scan: `require_menu_bar_for_desktop`, `require_apple_sign_in`,
`require_route_transition_consistency`, `prefer_shell_route_for_persistent_ui`,
`require_intl_locale_initialization`, `prefer_implicit_animations`. The other eight fire in
isolated / small-directory scans but show silent in the full corpus scan of the crowded
`example/lib/test` directory (32 files) — a **pre-existing scan-tooling limitation** (a rule
fires when its fixture is scanned alone or with one sibling, but not among ~30), the same
"fires per-file, zero under full-corpus scan" phenomenon already documented for the async
cluster in `plans/TODO_rule_metadata_completeness.md` §4.1. It is not a rule bug and not
introduced here; these rules were already in the silent list before this fix. The eight:
`require_error_state`, `avoid_circular_provider_deps`, `prefer_notifier_over_state` (new
fixtures, proven firing), and `require_window_close_confirmation`, `require_error_case_tests`,
`avoid_test_coupling`, `require_test_cleanup`, `prefer_test_variant`.

**Fixture repairs done** (these are whole-file rules; a fixture that places a BAD and a GOOD
example in one file lets the GOOD's file-wide "satisfied" flag — a `PlatformMenuBar`, an
`Intl.defaultLocale` init, a `didRequestAppExit`, a `throwsA`, a `tearDown` — mask the BAD):
the compliant example was moved to a sibling `*_good.dart` for `require_menu_bar_for_desktop`,
`require_apple_sign_in`, `require_intl_locale_initialization`, `require_test_cleanup`,
`avoid_test_coupling`, and `require_error_case_tests`. `require_window_close_confirmation`'s
fixture was renamed to a `_desktop` path and given a real violating observer (a
WidgetsBindingObserver subclass with no `didRequestAppExit`). `require_error_case_tests` was
moved into a `/test/` path. `avoid_test_coupling`'s coupled tests were moved into a top-level
`main()` (the rule only inspects `main`). Mock classes `GoogleSignIn`, `CupertinoPageRoute`,
and `FadeTransitionRoute` were added to `example/lib/flutter_mocks.dart` so the
constructor-based rules resolve. New fixtures were authored for the three rules that had
none: `require_error_state`, `avoid_circular_provider_deps`, `prefer_notifier_over_state`.

**Extra rule-logic fix folded in:** `require_apple_sign_in` (v3) matched only identifier
receivers (`isExactTarget`), so the standard `GoogleSignIn().signIn()` shape — a
constructor-call receiver, and the rule's own documented bad example — never matched even
after the engine fix. Now handled explicitly in the rule's visitor.

**14 call sites** reported inside the discarded callback (the original inventory of 9
was incomplete — a full grep of the rules tree found 5 more). All now converted:

| Rule | File | Version bump | Notes |
|---|---|---|---|
| `require_menu_bar_for_desktop` | `core/performance_rules.dart` | v4 → v5 | |
| `require_window_close_confirmation` | `core/performance_rules.dart` | v3 → v4 | |
| `require_error_state` | `packages/bloc_rules.dart` | v3 → v4 | |
| `avoid_circular_provider_deps` | `packages/riverpod_rules.dart` | v1 → v2 | |
| `prefer_notifier_over_state` | `packages/riverpod_rules.dart` | v2 → v3 | |
| `require_apple_sign_in` | `platforms/ios_ui_security_rules.dart` | v2 → v3 | file was also missing the `ast/visitor.dart` import |
| `require_error_case_tests` | `testing/testing_best_practices_rules.dart` | v4 → v5 | |
| `avoid_test_coupling` | `testing/test_rules.dart` | v2 → v3 | already used `addCompilationUnit`; report loop was in the dead post-run — moved inline |
| `require_test_cleanup` | `testing/test_rules.dart` | v3 → v4 | |
| `prefer_test_variant` | `testing/test_rules.dart` | v3 → v4 | not in the original inventory |
| `require_route_transition_consistency` | `ui/navigation_rules.dart` | v4 → v5 | not in the original inventory |
| `prefer_shell_route_for_persistent_ui` | `ui/navigation_rules.dart` | v2 → v3 | not in the original inventory |
| `require_intl_locale_initialization` | `ui/internationalization_rules.dart` | v3 → v4 | not in the original inventory; also registered `addMethodInvocation` twice, so the native engine's single method-invocation slot silently dropped the first handler — merged into one visitor |
| `prefer_implicit_animations` | `ui/animation_rules.dart` | v2 → v3 | not in the original inventory |

(`require_animation_status_listener` in `ui/animation_rules.dart` was already converted
to `addCompilationUnit` in an earlier session and is not part of this batch.)

## Follow-up to prevent recurrence — DONE

Added `test/integrity/no_op_stub_registration_guard_test.dart`, which scans
`lib/src/rules/` and fails if any rule calls `addPostRunCallback`, `addFunctionBody`, or
`addFormalParameter` (matching a `.method(` call so the stub definitions and the
explanatory comments do not trip it). This is the strongest of the options considered
(the alternatives — `@Deprecated` stubs, or debug-build asserts — were not needed once
the guard test made a dead registration fail CI). The three stubs remain in
`saropa_context.dart` so v4-ported rules still compile; the guard ensures no new rule
reaches for them.

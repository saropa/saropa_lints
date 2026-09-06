# Five False-Positive Lint Rule Fixes

Five lint rules from the contacts project sweep were producing false positives on correct code. Each was fixed independently via parallel agents, then merged and reviewed.

## Finish Report (2026-09-06)

### Defects Fixed

1. **`require_copy_with_null_handling`** — fired on `copyWith` methods where all fields using `??` are non-nullable types (e.g. `bool`). The sentinel/wrapper pattern the rule suggests adds no value when fields cannot be null. Fix: added `_collectNullableFieldNames()` to check class field nullability before emitting; uses `bodyMembers` compat shim from `analyzer_compat.dart`.

2. **`require_permission_manifest_android`** — fired unconditionally on every `permission_handler` import, asserting the manifest entry was missing. The rule operates purely at the Dart AST level and cannot read `AndroidManifest.xml`. Fix: downgraded severity from WARNING to INFO, reworded message to advisory.

3. **`require_url_launcher_queries_android`** — same structural limitation as #2. Fired on every `url_launcher` import asserting `<queries>` blocks were missing. Fix: downgraded to INFO with advisory wording.

4. **`require_workmanager_for_background`** — fired on all `Timer.periodic` calls including UI-only timers in `State` subclasses with proper `cancel()` in `dispose()`. Fix: added `_isTimerInDisposableState()` that checks for State lifecycle and delegates to `isBackgroundWorkCanceledInDispose` from `target_matcher_utils.dart`.

5. **`avoid_ios_battery_drain_patterns`** — same false positive as #4 on widget-bound timers. Fix: added equivalent `_isTimerInDisposableState()` with the same `endsWith('State')` check as #4 and same delegation to `isBackgroundWorkCanceledInDispose`.

### Code Review Findings (applied)

The two `_isTimerInDisposableState` implementations initially diverged: workmanager's used `endsWith('State')` (catching `ConsumerState`, `TickerProviderState`), while iOS battery drain's used exact `== 'State'`. Aligned both to use `endsWith('State')` and `thisOrAncestorOfType<ClassDeclaration>()` for consistency.

**Reflection-gate hardening:** extracted the duplicated private `_isTimerInDisposableState` helpers from both rules into a single shared `isTimerLifecycleBoundToDisposableState()` in `target_matcher_utils.dart`. Both `require_workmanager_for_background` and `avoid_ios_battery_drain_patterns` now call the shared helper. Added a ConsumerState test case to the iOS battery drain test suite (4 cases total).

### Known Limitations

- **Name-matching approach** (copyWith rule): parameter names must match field names. Renamed parameters (`copyWith({String? newName})` backing field `name`), inherited fields from superclasses, typedef-hidden nullability, and fields without explicit type annotations are not detected. Accepted trade-off for the common case.
- **`endsWith('State')` check** (timer rules): could match unrelated user classes literally named `...State` that aren't Flutter State subclasses. Consistent with existing convention used elsewhere in the codebase.
- **`dispose()` body-only inspection**: if `dispose()` delegates cancellation to a private helper method, the timer is not recognized as lifecycle-managed and the false positive persists.

### Test Coverage

- `test/rules/platforms/avoid_ios_battery_drain_patterns_disposable_state_test.dart` — 4 cases (State+cancel, State without cancel, ConsumerState+cancel, non-State service)
- `test/rules/widget/widget_patterns_rules_test.dart` — severity assertion for permission manifest rule
- `example_packages/lib/packages/require_copy_with_null_handling_fixture.dart` — 4 fixture cases
- `example_packages/lib/workmanager/require_workmanager_for_background_fixture.dart` — 4 fixture cases
- `test/support/syntactic_rule_harness.dart` — new harness for syntactic-only rule testing

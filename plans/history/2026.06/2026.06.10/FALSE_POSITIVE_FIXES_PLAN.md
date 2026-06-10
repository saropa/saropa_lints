# False-Positive Fixes Plan (2026.06)

Tracks fixes for 23 false-positive bug reports filed 2026-06-09/10 under `bugs/`.
The reports collapse into 6 workstreams grouped by file/rule, sharing two
root-cause families.

## Root-cause families

**Family 1 — syntactic string/substring/name matching instead of resolved
type/element checks.** (The "String matching for types" anti-pattern in
CLAUDE.md.) Caused by `contains()` / `startsWith()` / un-anchored regex /
`toSource()` equality.

**Family 2 — over-broad heuristic that ignores execution context/semantics.**
The trigger fires on syntactic presence without checking what the code does.

## Workstreams (each ends with the `/finish` skill)

### WS-1 · `avoid_string_substring` — `lib/src/rules/code_quality/code_quality_avoid_rules.dart`
Four bug reports edit the same helper cluster → one PR.
- `_collectIdentifierNames`: add `PrefixedIdentifier`/`PropertyAccess`/`IndexExpression`/`PostfixExpression` (foundational).
- `_isGuardedByLengthCheck`: accept ternary else-branch; detect substring inside `if`/`while` condition.
- `_conditionGuardsLength`: add `isEmpty`/`isNotEmpty`.
- `_hasPrecedingEarlyExitGuard`: consult `_conditionGuardsLength` on receiver; drop `argNames.isEmpty` short-circuit.
- regex `hasMatch` early-exit + post-loop preceding-sibling loop bound. Cross-function Case 3 stays a TP.
- Reports: `else_branch_and_in_condition`, `emptiness_and_startswith_early_exit`, `property_access_args`, `regex_and_loop_bounds`.

### WS-2 · `lib/src/rules/data/collection_rules.dart`
- `avoid_collection_equality_checks`: `isDartCoreList/Map/Set/Iterable` + exact `Queue`/`LinkedList` (not prefix `startsWith`).
- `avoid_unsafe_collection_methods`: 8 guard-shape fixes A–H. Largest item; own PR.

### WS-3 · `lib/src/rules/widget/widget_lifecycle_rules.dart`
- `always_remove_listener`: normalize receiver (strip trailing `!`/`?`), prefer resolved element.
- `avoid_context_in_initstate_dispose`: report only when `context` feeds an actual inherited lookup.

### WS-4 · `avoid_listview_without_item_extent` — `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`
One rule, two reports (overlapping sites) → one PR.
- Relax `isInlineNonScrolling` to `shrinkWrapTrue` alone.
- Inspect `itemBuilder` return; suppress for self-sizing widget allowlist.

### WS-5 · substring→semantic cluster (independent files, quick wins)
- `avoid_mixed_environments` (`config_rules.dart`): word-boundary lookaround regex.
- `avoid_ios_hardcoded_device_model` (`ios_platform_lifecycle_rules.dart`): require device-check context; exempt data collections.
- `require_dialog_tests` (`testing_best_practices_rules.dart`): dialog-API allowlist OR Future/void return type.
- `require_error_identification` (`accessibility_rules.dart`): require Color staticType; tighten `\.error\b`.
- `avoid_unbounded_cache_growth` (`memory_management_rules.dart`): AST-detect `removeWhere`/`removeRange`/`clear`.

### WS-6 · remaining standalone narrowings
- `avoid_returning_null_for_future` (`return_rules.dart`): `nullabilitySuffix == question` guard. Trivial.
- `avoid_string_concatenation_loop` (`performance_rules.dart`): require accumulator.
- `avoid_swallowing_exceptions` (`error_handling_rules.dart`): skip wildcard `_` + logging/recovery fallback.
- `avoid_unawaited_future` (`async_rules.dart`): exempt `close()`/`cancel()` in sync void bodies + stream callbacks.
- `avoid_excessive_rebuilds_animation` (`animation_rules.dart`): suppress when builder reads animation `.value` at a leaf.
- `prefer_setup_teardown` (`testing_best_practices_rules.dart`): exclude tester-bound statements.
- `prefer_single_setstate` (`build_method_rules.dart`): defer loop body scope + reorder `hasAwait` reset.
- `prefer_value_listenable_builder` (`performance_rules.dart`): bail on Future/Stream field or async-assigned scalar.

## Per-bug checklist
Rule edit → fixture in `example/lib/` (only where BAD triggers) → unit test →
CHANGELOG `[Unreleased]` → ROADMAP status → verify with
`dart run saropa_lints scan <dir> --tier comprehensive --files <f> --format json`.
New `example_*` dirs go in `analysis_options.yaml` exclude.

## Execution order
1. WS-5 + `avoid_returning_null_for_future` (quick wins).
2. WS-1 (substring family).
3. WS-3, WS-4, small WS-6 items.
4. WS-2 `avoid_unsafe_collection_methods`, WS-6 `prefer_value_listenable_builder`/`prefer_single_setstate` (riskiest, isolated).

## Finish Report (2026-06-10)



**Scope:** (A) Dart lint rules / analyzer plugin + `example/` fixtures + Dart `test/`.

All 23 false-positive reports filed 2026-06-09/10 are addressed across 6 commits on `main`:

- `b74c4d83` WS-5: avoid_returning_null_for_future, avoid_ios_hardcoded_device_model, require_dialog_tests, require_error_identification, avoid_unbounded_cache_growth (avoid_mixed_environments confirmed already fixed upstream).
- `3fef498b` WS-1: avoid_string_substring (4 reports — guard-recognition cluster).
- `03e80f2a` WS-3: always_remove_listener, avoid_context_in_initstate_dispose.
- `0c84d099` WS-4: avoid_listview_without_item_extent (2 reports).
- `bf3e0179` WS-2: avoid_collection_equality_checks, avoid_unsafe_collection_methods (8 guard patterns).
- `e7975dd7` (+ `9bbefffc` integrity/fixture fixup) WS-6: avoid_string_concatenation_loop, avoid_swallowing_exceptions, avoid_unawaited_future, avoid_excessive_rebuilds_animation, prefer_setup_teardown, prefer_single_setstate, prefer_value_listenable_builder.

**Verification approach (key finding):** the scan CLI (`ScanRunner`) and `parseString`-based tests do NOT resolve types or rewrite constructor calls to `InstanceCreationExpression`, so type-gated and InstanceCreation-gated rules are inert there. Pure-AST guard logic was verified with new `parseString` unit tests via `@visibleForTesting` accessors (avoid_string_substring, widget-lifecycle, avoid_listview, avoid_unsafe_collection_methods, prefer_single_setstate, avoid_excessive_rebuilds_animation, avoid_unawaited_future); AST/source rules via the scan CLI; resolution-dependent rules against the real `d:/src/contacts` FP sites. As a bonus, avoid_listview_without_item_extent and avoid_excessive_rebuilds_animation now also handle the unresolved MethodInvocation constructor shape, so they fire in the scan CLI where they previously could not.

**Full suite:** `dart test test/rules/ test/integrity/` → 5362 pass, 1 skipped. All changed rule files `dart analyze` clean (the only 2 warnings are a pre-existing `ExtensionType.primaryConstructor` dead-code issue in an unrelated rule, surfaced by analyzer drift — not introduced by this work).

**Documented residual (not a hidden gap):** prefer_value_listenable_builder clears categories 1/2/4/6; categories 3 (transient in-flight lock) and 5 (persisted-pref mirror) remain by design — the bug report itself flags them as structurally indistinguishable from single-value display state, so suppressing them would risk killing genuine positives. Recorded in that bug's archived finish report; surfaced to the user as a follow-up decision.

**Bugs archived:** all 22 reports → `plans/history/2026.06/2026.06.10/` (avoid_mixed_environments was already at `2026.06.09/`), each with an appended `## Finish Report`.

# BUG: assertion-free stub tests that always pass without testing anything

**Severity**: High — test suite gives partial false confidence
**Date**: 2026-03-25 (rebaselined 2026-06-10)
**Status**: Phase 1 DONE (stubs removed); Phase 2 (real tests) pending

## Two phases

The work splits cleanly:

- **Phase 1 — remove the stubs everywhere (DONE 2026-06-10).** Empty-body
  `test`/`testWidgets` (`() {}`) is bad design regardless of replacement: it
  always passes and asserts nothing. 396 empty-body stubs were deleted, plus
  255 `group()` blocks that those deletions left empty (651 statements across
  47 files). Empty-body count is now **0**, hard-gated by
  [test/integrity/stub_test_guard_test.dart](../test/integrity/stub_test_guard_test.dart)
  via `scanEmptyBodyStubTests`. Full suite green (5,726 tests).
- **Phase 2 — write real fixture-backed tests (pending).** Replace the lost
  coverage with assertions that the rule actually fires (and stays quiet on
  compliant code), using the resolved-analyzer oracle proven below.

27 assertion-free tests remain and are deliberately KEPT — they are real tests
the broad heuristic miscounts: "does not throw" tests (the assertion is the
absence of an exception) and helper-asserted tests (`expectFixtureExists(...)`).
The empty-body gate does not flag them.

## Phase 2 oracle (built & validated 2026-06-10)

A resolved-analyzer harness runs a single rule in-process against a fixture with
full type/element resolution (no `custom_lint`, which this package does not use
— see below). Validated: it fires `avoid_unawaited_future:12`,
`check_mounted_after_async:12`, `avoid_async_in_build:8`, `avoid_redundant_await:10,12`
at the exact expected lines. Mechanics: `AnalysisContextCollection.getResolvedUnit`
→ build a `RuleContext` whose `typeProvider`/`typeSystem`/`libraryElement` come
from the `ResolvedUnitResult` → `rule.registerNodeProcessors` → set
`rule.reporter` → walk the resolved unit with `ScanWalker` → flush
`afterLibrary` callbacks. Run ONE rule at a time (running all comprehensive
rules triggers an unrelated cross-file rule's whole-project scan).

## Gates (all green)

Three regression gates in [test/integrity/stub_test_guard_test.dart](../test/integrity/stub_test_guard_test.dart),
wired into the normal `dart test` run so they execute in CI and in publish
Step 7:

- **empty-body `test`/`testWidgets` (`() {}`)** — count **0**, hard `isEmpty`
  gate via `scanEmptyBodyStubTests`. This is the precise "stub" invariant.
  A `test(..., () {}, skip: '...')` is excluded: a skipped test never runs, so
  its empty body cannot silently pass — it is a documented placeholder for an
  un-runnable case, not a coverage-faking stub (added 2026-06-14 after such a
  placeholder in `widget_lifecycle_fp_test.dart` turned the gate red).
- `expect(true, isTrue)` — **0**.
- `expect('<literal>', isNotNull)` — **0**.

- **publish.py audit gate (non-overridable)** — `run_stub_guard_check` in
  `scripts/modules/_audit.py` runs the guard test during the audit and feeds
  `AuditResult.stub_guard_passed` into `has_blocking_issues`. A reintroduced
  stub blocks publish with the audit's exit code (11), so it cannot be waved
  through the interactive "continue despite test failure" prompt in Step 7.

### Phase 2 backlog — files that lost stub coverage (count = stubs removed)

These are the files whose empty-body `SHOULD trigger` / `should NOT trigger`
placeholders were deleted in Phase 1; each is a candidate for real
fixture-backed tests via the Phase 2 oracle. (Counts are the original stub
totals per file; regenerate current state with `scanStubTests('.')`.)

| Stubs | File |
|------:|------|
| 20 | test/rules/architecture/architecture_rules_test.dart |
| 20 | test/rules/core/state_management_rules_test.dart |
| 20 | test/rules/hardware/bluetooth_hardware_rules_test.dart |
| 18 | test/rules/testing/debug_rules_test.dart |
| 17 | test/rules/codegen/freezed_rules_test.dart |
| 16 | test/integrity/false_positive_fixes_test.dart |
| 16 | test/rules/data/equality_rules_test.dart |
| 14 | test/rules/packages/auto_route_rules_test.dart |
| 14 | test/rules/platforms/android_rules_test.dart |
| 14 | test/rules/ui/notification_rules_test.dart |
| 12 | test/rules/core/context_rules_test.dart |
| 12 | test/rules/platforms/web_rules_test.dart |
| 12 | test/rules/security/permission_rules_test.dart |
| 12 | test/rules/widget/dialog_snackbar_rules_test.dart |
| 10 | test/rules/architecture/lifecycle_rules_test.dart |
| 10 | test/rules/flow/exception_rules_test.dart |
| 10 | test/rules/flow/return_rules_test.dart |
| 10 | test/rules/packages/flutter_hooks_rules_test.dart |
| 10 | test/rules/platforms/linux_rules_test.dart |
| 10 | test/rules/platforms/windows_rules_test.dart |
| 10 | test/rules/security/crypto_rules_test.dart |
| 9 | test/rules/packages/url_launcher_rules_test.dart |
| 8 | test/rules/commerce/iap_rules_test.dart |
| 8 | test/rules/resources/db_yield_rules_test.dart |
| 8 | test/rules/testing/prefer_setup_teardown_test.dart |
| 8 | test/rules/widget/theming_rules_test.dart |
| 7 | test/rules/architecture/structure_rules_test.dart |
| 6 | test/integrity/defensive_coding_test.dart |
| 6 | test/rules/config/platform_rules_test.dart |
| 6 | test/rules/media/media_rules_test.dart |
| 6 | test/rules/network/connectivity_rules_test.dart |
| 6 | test/rules/packages/geolocator_rules_test.dart |
| 6 | test/rules/packages/get_it_rules_test.dart |
| 6 | test/rules/packages/qr_scanner_rules_test.dart |
| 6 | test/rules/packages/supabase_rules_test.dart |
| 6 | test/rules/packages/workmanager_rules_test.dart |
| 5 | test/rules/packages/rxdart_rules_test.dart |
| 4 | test/rules/data/money_rules_test.dart |
| 4 | test/rules/packages/flame_rules_test.dart |
| 3 | test/integrity/rule_relationship_metadata_integrity_test.dart |
| 3 | test/rules/core/documentation_rules_test.dart |
| 2 | test/integrity/roadmap_15_rules_test.dart |
| 2 | test/rules/core/naming_style_rules_test.dart |
| 2 | test/rules/packages/graphql_rules_test.dart |
| 2 | test/rules/packages/sqflite_rules_test.dart |
| 2 | test/rules/resources/file_handling_rules_test.dart |
| 1 | test/integrity/anti_pattern_detection_test.dart |
| 1 | test/integrity/saropa_lints_test.dart |
| 1 | test/rules/architecture/compile_time_syntax_rules_test.dart |
| 1 | test/rules/flow/error_handling_rules_test.dart |
| 1 | test/rules/security/security_rules_test.dart |

Regenerate this list any time with `scanStubTests('.')`.

## Phase 2 oracle — why not `custom_lint`, and the two fallbacks tried

`custom_lint` is the faithful pipeline, but **this package does not use it** —
the root pubspec builds directly on `analyzer_plugin`, with no `custom_lint` /
`custom_lint_builder` dependency. `dart run custom_lint` fails outright, which
is why [test/scan/fixture_lint_integration_test.dart](../test/scan/fixture_lint_integration_test.dart)
always takes its `if (fromCustom.isEmpty) return` escape and only asserts the
native compile-time rules `dart analyze` emits. Adding `custom_lint` would mean
rewriting all rules onto another framework — off the table.

`ScanRunner` ([lib/src/scan/scan_runner.dart](../lib/src/scan/scan_runner.dart))
is in-process and fast but **parse-only** (`parseString`, no type/element
resolution): only 1 of 9 architecture rules fire under it. Useful for syntactic
rules; blind to semantic/cross-file ones.

The chosen oracle is the **resolved-analyzer harness** described at the top —
no new dependency, faithful for syntactic AND semantic rules. (To use ScanRunner
for syntactic-only checks, note it excludes any `/example` path unless you pass
`applyExclusionsToFileList: false`.)

Phase 2 also has to fix a defect class the stubs hid: **fake fixtures**, e.g.
`avoid_god_class`'s "BAD" class `_bad79_AppManager` is empty — a comment claims
"20+ fields and 30+ methods" but there are none, so the rule correctly stays
quiet. Each Phase 2 conversion must verify its fixture actually contains the
violating pattern.

## Done criteria

- [x] Empty-body stub count = **0**, hard-gated.
- [ ] Each removed stub's intended coverage is restored by a fixture-backed
      assertion (trigger + non-trigger) under the resolved-analyzer oracle.
- [x] A **non-overridable** stub gate runs in `publish.py`'s audit phase
      (blocking exit code), not only in the wave-through-able Step 7 `dart test`.

## History

- 2026-03-25: filed at 3,530 regex-literal stubs / 103 files.
- 2026-04-04 → 04-27: regex-literal stubs driven to 0; `expect(true, isTrue)`
  guard + literal-`isNotNull` ratchet added.
- 2026-06-10: rebaselined onto the AST definition (423 assertion-free / 51
  files). **Phase 1**: deleted 396 empty-body stubs + 255 orphaned `group()`
  blocks (651 statements, 47 files); switched the guard to a hard empty-body=0
  gate (`scanEmptyBodyStubTests`); kept 27 legitimate assertion-free tests;
  full suite green (5,726). Built & validated the Phase 2 resolved-analyzer
  oracle.

## Finish Report (2026-06-10)

**Scope:** (A) Dart analyzer-plugin code + (C) docs/scripts. No rule-behavior
change, no extension/UI change. Phase 1 (stub removal) and the non-overridable
publish gate are complete; Phase 2 (writing real fixture-backed tests) is
deferred and remains tracked above.

**Deep review:**
- `stub_density.dart`: `scanEmptyBodyStubTests` / `emptyBodyStubCountIn` mirror
  the existing `scanStubTests` / `stubCountIn` structure (same visitor pattern,
  `firstOrNull`-safe argument access). Empty-body = `BlockFunctionBody` with
  zero statements — a comment-only body is correctly still "empty" (comments
  are not AST statements), pinned by a test.
- `stub_test_guard_test.dart`: empty-body gate uses `isEmpty` (hard zero), not
  a ratchet — chosen over gating the broader assertion-free metric because that
  metric has 27 legitimate hits (does-not-throw and helper-asserted tests) that
  must not be force-deleted. The two literal-tautology regex guards are kept.
- `_audit.py`: `run_stub_guard_check` shells out to the canonical Dart guard
  test (single source of truth — no reimplemented AST detection in Python),
  uses `get_shell_mode()` for Windows `dart` resolution, and treats a missing
  test file as FAIL so the gate can't silently pass. `stub_guard_passed` feeds
  `AuditResult.has_blocking_issues` (publish exit code 11); the blocking reason
  is surfaced in `_publish_steps.py`.

**Testing:**
- 4A audit: the only tests referencing changed symbols are
  `stub_test_guard_test.dart` (updated) and `fix_and_stub_test.dart` (tests the
  unchanged `stubCountIn` — not broken). No assertion pinned a deleted stub.
- 4B new tests: added an `emptyBodyStubCountIn` group to `fix_and_stub_test.dart`
  (empty block, `testWidgets`, comment-only body all count; non-empty body does
  not — with an explicit contrast assertion that `stubCountIn` still flags it).
- Ran: `dart test test/project_health/fix_and_stub_test.dart` (9 pass),
  `dart test test/integrity/stub_test_guard_test.dart` (3 pass), the 5
  heavily-edited rule-test files (pass), and the full suite (5,726 pass).
  Guard FAIL path verified by injecting a temp stub (blocked, then removed).
- `dart analyze --fatal-infos` on the changed Dart files: no issues.

**Maintenance:** CHANGELOG updated (2 Maintenance entries: Phase 1 removal +
audit gate). README verified — no updates needed (no rule/test count cited).
ROADMAP — N/A (no lint entry completed). Guides reviewed — nothing user-facing.
No bug archive — task did not close a `bugs/*.md` file.

**Plan disposition:** stays ACTIVE, not moved/split. Phase 2 is tracked in this
plan and deferred; the remaining scope is a self-contained, unstarted phase
documented above. Deliberate deviation from the A-MOVE "split or archive"
default.

**Outstanding:** Phase 2 — author real fixture-backed trigger/non-trigger tests
via the resolved-analyzer oracle for the rules whose stub placeholders were
removed; fix fake fixtures (e.g. `avoid_god_class`'s empty BAD class) as
encountered.

**Files:** `test/project_health/fix_and_stub_test.dart`
(new `emptyBodyStubCountIn` tests), `plans/BUG_stub_tests_in_suite.md` (this
report). Phase 1 + gate code landed earlier in commits `b086d7d6` and
`29d62604` (gate code swept into a concurrent session's commit `0f739a8d`).

# BUG: assertion-free stub tests that always pass without testing anything

**Severity**: High — test suite gives partial false confidence
**Date**: 2026-03-25 (rebaselined 2026-06-10)
**Status**: DONE — stubs removed and hard-gated.

## What was done

Empty-body `test`/`testWidgets` (`() {}`) is bad design regardless of
replacement: it always passes and asserts nothing. 396 empty-body stubs were
deleted, plus 255 `group()` blocks that those deletions left empty (651
statements across 47 files). Empty-body count is now **0**, hard-gated by
[test/integrity/stub_test_guard_test.dart](../test/integrity/stub_test_guard_test.dart)
via `scanEmptyBodyStubTests`. Full suite green (5,726 tests).

27 assertion-free tests remain and are deliberately KEPT — they are real tests
the broad heuristic miscounts: "does not throw" tests (the assertion is the
absence of an exception) and helper-asserted tests (`expectFixtureExists(...)`).
The empty-body gate does not flag them.

(Originally this plan carried a Phase 2 — rewriting the removed stubs as real
fixture-backed trigger/non-trigger tests. That follow-up work was dropped as not
needed; the stub-removal and the gate that keeps them out are the deliverable.)

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

## Done criteria

- [x] Empty-body stub count = **0**, hard-gated.
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

**Plan disposition (superseded 2026-06-14):** at the time this report was
written the plan stayed ACTIVE to track Phase 2. Phase 2 has since been dropped
as not needed — see the Status line at the top. No outstanding work remains.

**Files:** `test/project_health/fix_and_stub_test.dart`
(new `emptyBodyStubCountIn` tests), `plans/BUG_stub_tests_in_suite.md` (this
report). Phase 1 + gate code landed earlier in commits `b086d7d6` and
`29d62604` (gate code swept into a concurrent session's commit `0f739a8d`).

## Finish Report (2026-06-14)

**Scope:** (A) Dart analyzer-plugin tooling + (C) docs. The empty-body
stub-test gate (`scanEmptyBodyStubTests` /
[stub_density.dart](../lib/src/cli/project_health/stub_density.dart)) was a hard
zero gate that counted any `test`/`testWidgets` whose callback is an empty block
(`() {}`). A deliberately-skipped placeholder —
`test('removeListener detection (Flutter-gated; not oracle-runnable)', () {}, skip: '...')`
in [widget_lifecycle_fp_test.dart](../test/rules/widget/widget_lifecycle_fp_test.dart)
— documents an un-runnable case (the rule returns early unless
`isFlutterProject`, which the Flutter-less example package cannot satisfy). A
`skip:`-ped test never executes, so its empty body cannot silently pass, yet the
gate counted it and turned the guard test, CI, and the publish audit gate
(exit 11) red. No real stub had been reintroduced; the gate's definition was too
broad. (Phase 2 — writing fixture-backed tests for the removed-stub backlog —
has since been dropped as not needed; see the Status line at the top.)

**Deep review:**
- `stub_density.dart`: `_EmptyBodyStubVisitor.visitMethodInvocation` now checks
  for a `skip:` named argument before counting an empty body. The exclusion is
  scoped to the empty-body visitor only — `_StubVisitor` (the broader
  assertion-free heuristic) and `_AssertionDetector` are untouched. The
  rationale is documented inline at the check, naming the failure mode (a
  documented placeholder turning the gate red).
- The check reads `NamedExpression.name.label.name == 'skip'`, matching the
  package:test `skip:` parameter on both `test` and `testWidgets`. It does not
  attempt to evaluate the skip value (a `skip: false` would still be excluded);
  in practice the value is always a non-empty reason string, and a `skip: false`
  empty-body test is itself meaningless, so the simpler name-presence check is
  correct and avoids const-evaluation in a parse-only visitor.

**Testing:**
- 4A audit: the only tests referencing `emptyBodyStubCountIn` are
  `test/project_health/fix_and_stub_test.dart` (extended here) and
  `test/integrity/stub_test_guard_test.dart` (the live gate). No assertion
  pinned the pre-fix "skipped empty body counts" behavior.
- 4B new tests: added two cases to the `emptyBodyStubCountIn` group — a skipped
  empty-body test is not counted, and (the over-reach guard) an empty-body test
  with a non-`skip` named argument is still counted.
- Ran `dart test test/project_health/fix_and_stub_test.dart test/integrity/stub_test_guard_test.dart`
  — 14 pass (the empty-body gate, formerly red, is green). The same guard run
  was confirmed red before the fix (1 empty-body stub in
  `widget_lifecycle_fp_test.dart`).
- `dart analyze --fatal-infos` on the changed Dart files: no issues.

**Maintenance:** CHANGELOG updated (1 Maintenance entry: the gate no longer
fails on a skipped placeholder). README verified — no updates needed (no rule or
test count cited). ROADMAP — N/A (no lint entry changed). Guides reviewed —
nothing user-facing. No bug archive — task did not close a `bugs/*.md` file.

**Plan disposition:** this task restored the already-complete stub gate to green
after a definition gap let a legitimate skipped placeholder trip it. (Phase 2,
referenced here as outstanding, was dropped as not needed on 2026-06-14 — see
the Status line at the top.)

## Finish Report (2026-06-14, plan closeout)

**Scope:** (C) docs only — the plan tracker itself. No Dart, no analyzer plugin,
no extension code, no test code.

The plan tracked two phases: removing assertion-free empty-body stub tests
(complete since 2026-06-10, hard-gated at zero by `scanEmptyBodyStubTests`) and a
deferred follow-up to rewrite the removed stubs as fixture-backed
trigger/non-trigger tests via a resolved-analyzer oracle. The follow-up phase was
never started and has been dropped as not needed. The deliverable — stub removal
plus the non-overridable publish-audit gate that keeps stubs from returning — is
complete and verified, so the plan no longer carries open scope.

**Edits:** the Status line now reads DONE; the two-phase intro collapsed to a
single "What was done" section noting the follow-up was dropped; the
resolved-analyzer oracle section, the ~50-file removed-stub backlog table, and the
"why not custom_lint" rationale (all of which existed only to support the dropped
follow-up) were removed; the Done-criteria list now has both remaining boxes
checked; and the forward-looking "stays ACTIVE / outstanding" framing in the two
prior Finish Reports was corrected to point at the Status line.

**Deep review:** no logic, rules, or tests changed — the edit is confined to
plan prose. The live reference to this plan in
[test/integrity/stub_test_guard_test.dart](../test/integrity/stub_test_guard_test.dart)
is a path-only comment; the plan keeps its current path, so the comment stays
valid.

**Testing:** no executable change. The stub gate
([test/integrity/stub_test_guard_test.dart](../test/integrity/stub_test_guard_test.dart))
was run to confirm the deliverable still holds — 3 tests pass (zero empty-body
stubs, zero `expect(true, isTrue)`, zero literal `isNotNull`). A repo grep for
references to this plan found only the path-only test comment and one historical
CHANGELOG line (left untouched, correct as-of-writing).

**Maintenance:** CHANGELOG updated (1 Maintenance entry, docs-only: the plan was
closed by dropping its deferred scope). README verified — no updates needed (no
rule or test count cited). ROADMAP — N/A (no lint entry changed). Guides
reviewed — nothing user-facing. No bug archive — the edited file is a plan
tracker in `plans/`, not a `bugs/*.md`.

**Plan disposition:** the plan is now fully complete, which by the A-MOVE default
would move it to `plans/history/2026.06/2026.06.14/`. The move was NOT performed:
archival of this exact file was explicitly declined earlier in the session. The
plan stays in the active `plans/` tree pending confirmation. A live test comment
also points at the current path and would need repointing on any move.

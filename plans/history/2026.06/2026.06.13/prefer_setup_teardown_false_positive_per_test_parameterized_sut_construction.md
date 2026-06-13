# BUG: `prefer_setup_teardown` — flags SUT construction that is parameterized per-test across the group

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-13
Rule: `prefer_setup_teardown`
File: `lib/src/rules/testing/testing_best_practices_rules.dart` (line ~3128, `_reportDuplicateSetup` / line ~3214 `_buildSetupSignature`)
Severity: False positive
Rule version: v7 | Since: — | Updated: —

---

## Summary

Three tests whose first line is `final sem = AsyncSemaphoreUtils(1);` are flagged
as duplicated setup, but the same `group()` also constructs the subject-under-test
with `AsyncSemaphoreUtils(2)` and `AsyncSemaphoreUtils(3)`. The construction is a
per-test parameterized arrange, not a shared fixture. The rule groups only by
**identical** signature, so it cannot see the sibling permit variants and
recommends a `setUp()` extraction that would leave a `late` field unused/shadowed
in the variant tests — not reducing duplication.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_setup_teardown'" lib/src/rules/
# lib/src/rules/testing/testing_best_practices_rules.dart:3068:    'prefer_setup_teardown',

# Negative — sibling repo only references it as CONFIG, not a definition
grep -rn "prefer_setup_teardown" ../saropa_drift_advisor/
# ../saropa_drift_advisor/analysis_options.yaml:144:  prefer_setup_teardown: false  (rule toggle only)
```

**Emitter registration:** `lib/saropa_lints.dart:985` (`PreferSetupTeardownRule.new`)
**Rule class:** `PreferSetupTeardownRule` — `lib/src/rules/testing/testing_best_practices_rules.dart:3048`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#3`

---

## Reproducer

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsyncSemaphoreUtils', () {
    test('permits getter', () {
      expect(AsyncSemaphoreUtils(3).permits, 3);          // permits = 3
    });

    test('serializes run blocks', () async {
      final AsyncSemaphoreUtils sem = AsyncSemaphoreUtils(1);   // permits = 1
      final List<String> log = <String>[];
      // ... uses sem and log ...
    });

    test('allows up to permits concurrent holders', () async {
      final AsyncSemaphoreUtils sem = AsyncSemaphoreUtils(2);   // permits = 2
      // ...
    });

    test('run returns the callback result', () async {          // LINT (false positive) — reported here
      final AsyncSemaphoreUtils sem = AsyncSemaphoreUtils(1);   // permits = 1
      expect(await sem.run<int>(() async => 11), 11);
    });

    test('release without acquire throws', () {
      final AsyncSemaphoreUtils sem = AsyncSemaphoreUtils(1);   // permits = 1
      expect(sem.release, throwsA(isA<StateError>()));
    });

    test('run releases the permit even when the callback throws', () async {
      final AsyncSemaphoreUtils sem = AsyncSemaphoreUtils(1);   // permits = 1
      await expectLater(sem.run<void>(() async => throw StateError('x')),
          throwsA(isA<StateError>()));
      expect(await sem.run<int>(() async => 5), 5);
    });

    test('toString reports counts', () async {
      final AsyncSemaphoreUtils sem = AsyncSemaphoreUtils(2);   // permits = 2
      // ...
    });
  });
}
```

The three tests whose **only** non-assertion statement is
`final sem = AsyncSemaphoreUtils(1);` share a signature and trip the threshold
of 3. The rule reports on the first of them. The group, however, builds the SUT
with permits 1, 2, and 3 — the `(1)` construction is one of three variants.

**Frequency:** Always, when ≥3 tests in a group construct the SUT with the same
literal argument while other tests in the same group construct it with different
literal arguments.

**Real occurrence:** `saropa_dart_utils/test/async/async_semaphore_utils_test.dart:41`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the SUT is constructed with a test-specific argument that varies across the group (1/2/3); this is arrange, not a hoistable shared fixture |
| **Actual** | `[prefer_setup_teardown]` reported on the first `AsyncSemaphoreUtils(1)` test |

---

## AST Context

```
CompilationUnit
  └─ MethodInvocation (group 'AsyncSemaphoreUtils')
      └─ FunctionExpression body
          ├─ MethodInvocation (test 'run returns the callback result')   ← reported
          │   └─ FunctionExpression () async { ... }
          │       └─ BlockFunctionBody
          │           ├─ VariableDeclarationStatement  final sem = AsyncSemaphoreUtils(1);  ← signature
          │           └─ ExpressionStatement           expect(...)   (assertion, skipped)
          ├─ MethodInvocation (test ... AsyncSemaphoreUtils(2) ...)   ← sibling variant, different signature
          └─ MethodInvocation (test ... AsyncSemaphoreUtils(3) ...)   ← sibling variant, different signature
```

---

## Root Cause

`_buildSetupSignature` (line ~3214) treats a constructor call with a literal
argument as a **body** statement (not a simple local init — `_isSimpleLocalInit`
excludes constructor invocations), so `final sem = AsyncSemaphoreUtils(1);`
becomes the signature. `_reportDuplicateSetup` (line ~3128) counts identical
signatures within a group and fires at `threshold` (3 when the file has no
`setUp`).

The blind spot: signatures are compared for **exact equality**, so
`AsyncSemaphoreUtils(1)`, `AsyncSemaphoreUtils(2)` and `AsyncSemaphoreUtils(3)`
are three distinct signatures. The rule counts the three `(1)` tests and reports,
unaware that the same construction with a *different literal* appears elsewhere in
the group. When the construction argument varies per test, hoisting `(1)` into a
`setUp()` does not remove duplication: the permits=2 and permits=3 tests must
still construct locally, shadowing or ignoring the hoisted `late` field. Net
result is a mixed pattern that is worse, not better.

This is the same class of problem the existing **Pattern 2** carve-out (line
~3097) addresses across groups ("different groups seed different data"), but it
occurs **within one group** when the shared call differs only by a literal
argument across sibling tests.

### Hypothesis A: detect the parameterized-SUT family

Before reporting a signature, check whether the same call **shape** (same
constructor/method name, same receiver) appears in the group with a *different*
literal argument. If so, the construction is parameterized arrange and is not a
hoistable fixture — suppress. Concretely: normalize the signature a second time
with literal arguments masked (e.g. `AsyncSemaphoreUtils(_)`), group by the
masked form, and if a masked group has ≥2 distinct concrete signatures, do not
report any of its members.

### Hypothesis B: do not treat single-line SUT construction as setup

A signature consisting of exactly one `final x = Ctor(literal);` body statement
(no side-effecting follow-up such as `.connect()`, `.open()`, `await …`) is
cheap object construction, not the kind of fixture `setUp()` exists for.
Optionally require the signature to contain a second non-assertion statement (the
actual side-effecting setup) before counting it.

---

## Suggested Fix

Hypothesis A is the targeted fix: mask literal arguments when grouping
signatures and skip any masked-group that has more than one concrete variant.
This keeps the rule firing on genuinely-identical repeated fixtures while
clearing the parameterized-construction false positive. Hypothesis B is a
broader policy change and should be weighed against existing fixtures that may
rely on single-line construction being flagged.

---

## Fixture Gap

The fixture for `prefer_setup_teardown` should include:

1. **Parameterized SUT construction across a group** — expect NO lint: 3 tests
   with `Foo(1)` plus sibling tests with `Foo(2)` / `Foo(3)` in the same group.
2. **Genuinely identical fixture** — expect LINT (regression guard): 3+ tests
   with the same `final db = Database(); db.open();` and no varying sibling.

---

## Changes Made

Implemented **Hypothesis A** (literal-masked grouping) in
`_reportDuplicateSetup` (`lib/src/rules/testing/testing_best_practices_rules.dart`):

- Added `_maskLiterals(String)` — masks string, numeric, and boolean literals in
  a normalized signature so `Foo(1)` / `Foo(2)` / `Foo(3)` collapse to `Foo(_)`.
  Word boundaries keep digit-bearing identifiers (`utf8`, `x1`) intact, and
  strings are masked before numbers so digits inside string literals don't leak
  into the numeric pass.
- `_reportDuplicateSetup` now builds a `masked signature → set of concrete
  signatures` map alongside the existing count map. Before reporting a signature
  that meets the threshold, it skips when the masked form has ≥2 concrete
  variants in the group — i.e. the construction is parameterized per test and
  hoisting one variant into `setUp()` removes no duplication.
- Genuinely-identical fixtures (no varying literal) keep exactly one variant per
  masked form, so they still report.
- Bumped the rule version marker `{v7}` → `{v8}`.

---

## Tests Added

Added two fixture functions to
`example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart`:

1. `_goodPreferSetupTeardownParameterizedSut` — five tests in one group
   constructing the SUT with permits `3`/`2`/`1`/`1`/`1`. The three `(1)` tests
   meet the threshold but the `(2)`/`(3)` siblings prove parameterization;
   expect **no** lint.
2. The existing `_badPreferSetupTeardownDuplicated` (identical
   `_DupRepo()`/`_DupSut(repo)` setup) remains as the regression guard; expect
   lint.

Verified via the scan CLI on a standalone `*_test.dart` reproducer (the rule is
`FileType.test`-only, so `example/lib` fixtures are not executed by CI): the
parameterized group emits no diagnostic and the genuinely-duplicated group still
fires once on its first test.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.7
- Dart SDK version: 3.12.1 (stable)
- custom_lint version: (transitive via saropa_lints ^13.12.7)
- Triggering project/file: `saropa_dart_utils/test/async/async_semaphore_utils_test.dart:41`

---

## Finish Report (2026-06-13)

### What the change does

`prefer_setup_teardown` previously grouped tests within a `group()` by the exact
text of their leading non-assertion setup statement and reported when an
identical signature recurred at or above the threshold (3 when the file has no
`setUp`, 4 when it does). The comparison was exact-equality, so it could not see
that a construction differing only by a literal argument
(`AsyncSemaphoreUtils(1)` vs `(2)` vs `(3)`) is one parameterized family rather
than a hoistable shared fixture. Three `(1)` tests met the threshold and were
flagged even though the sibling `(2)`/`(3)` tests proved the permit count is
per-test arrange.

The fix adds a literal-masked second view of each signature. In
`_reportDuplicateSetup`, a `masked signature → set of concrete signatures` map is
built alongside the existing count map. A new `_maskLiterals(String)` helper
replaces string, numeric, and boolean literals with `_`, so `Foo(1)`, `Foo(2)`,
and `Foo(3)` collapse to the masked form `Foo(_)`. Strings are masked before
numbers so digits inside string literals do not reach the numeric pass, and
`\b` word boundaries keep digit-bearing identifiers (`utf8`, `x1`) intact.
Before a signature meeting the threshold is reported, the rule checks its masked
form: if two or more distinct concrete variants exist in the group, the
construction is parameterized arrange and is suppressed. Genuinely-identical
setup yields exactly one concrete variant per masked form, so it still reports.

This is the within-group analogue of the existing cross-group "Pattern 2"
carve-out: there, different groups seed different data; here, sibling tests in
one group construct the subject with a different literal.

### Files changed

- `lib/src/rules/testing/testing_best_practices_rules.dart` — added
  `_maskLiterals`; extended `_reportDuplicateSetup` with the masked-variant
  carve-out; bumped the diagnostic message marker `{v7}` → `{v8}`.
- `example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart` —
  added `_goodPreferSetupTeardownParameterizedSut` (five tests building the SUT
  with permits 3/2/1/1/1; expect no lint). The existing
  `_badPreferSetupTeardownDuplicated` remains the regression guard.
- `test/rules/testing/prefer_setup_teardown_test.dart` — added a pin asserting
  the new GOOD fixture function exists and carries no `expect_lint`.
- `CHANGELOG.md` — `[Unreleased] → ### Fixed` entry.

### Verification

- `dart analyze` on the rule file: clean (`No issues found!`).
- `dart test` on `prefer_setup_teardown_test.dart`,
  `testing_best_practices_rules_test.dart`, and
  `false_positive_fixes_test.dart`: 94 passed.
- Scan CLI on a standalone `*_test.dart` reproducer (the rule is
  `FileType.test`-only, so `example/lib` fixtures are not executed by CI): the
  parameterized permits-1/2/3 group emits no diagnostic; the
  genuinely-duplicated group still fires once on its first test.

### Outstanding

None. The fix is scoped to the false-positive class described above; no quick
fix is applicable (the correct behavior is suppression, not a code rewrite).

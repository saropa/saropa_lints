# BUG: `prefer_setup_teardown` — Signature Comparison Truncates to First Two Statements, Missing Per-Test Divergence

**Status: Open**

Created: 2026-09-18
Rule: `prefer_setup_teardown`
File: `lib/src/rules/testing/testing_best_practices_rules.dart` (line ~3145)
Severity: False positive
Rule version: v8 (LintCode message `{v8}`; the class dartdoc header says "Rule version: v7" — stale relative to the emitted code; treat v8, the emitted value, as authoritative) | Since: v2.5.0 | Updated: v4.14.5

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

Three groups of tests (in `schema_handler_test.dart`, `handler_integration_test.dart`, `snapshot_handler_test.dart`) are flagged as sharing "duplicated setup" even though each test in the group passes different arguments (mock data, a capturing closure) or a different follow-on call sequence to reach its own distinct precondition. This is not a masked-literal miss (the rule already has a carve-out for that, per `plans/history/2026.04/2026.04.29/prefer_setup_teardown_false_positive_parameterized_sut_call.md` and `2026.06.13/prefer_setup_teardown_false_positive_per_test_parameterized_sut_construction.md`) — it is a **different** mechanism: the signature the rule compares is built from only the *first two* qualifying statements of each test body, so the differences these tests actually have (a third/fourth statement's differing arguments, or a differing sequence of setup calls after the first two) sit entirely outside the window the rule ever looks at.

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_setup_teardown'" lib/src/rules/
lib/src/rules/testing/testing_best_practices_rules.dart:3145:    'prefer_setup_teardown',

$ grep -rn "'prefer_setup_teardown'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches, confirms the rule is not defined downstream)
```

**Emitter registration:** `lib/src/rules/testing/testing_best_practices_rules.dart:3145` (barrel-exported at `lib/src/rules/all_rules.dart:107`)
**Rule class:** `PreferSetupTeardownRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Minimal reduction of the `snapshot_handler_test.dart` case (the cleanest of the three — no masked-literal involvement at all):

```dart
import 'package:test/test.dart';

Future<void> startServer() async { /* starts a server on a random port */ }
Future<dynamic> httpPost(int port, String path) async => null;

void main() {
  group('SnapshotHandler', () {
    test('GET /api/snapshot returns null when none captured', () async {
      await startServer();
      final resp = await httpPost(0, '/api/snapshot');
      // asserts nothing was captured
    });

    // LINT (false positive) — flagged as duplicating the test below and a
    // third sibling, even though its subsequent assertions diverge entirely.
    test('POST /api/snapshot creates snapshot with metadata', () async {
      await startServer();
      await httpPost(0, '/api/snapshot');
      // asserts metadata fields on the created snapshot
    });

    test('DELETE /api/snapshot clears snapshot', () async {
      await startServer();
      await httpPost(0, '/api/snapshot');
      // deletes the snapshot, then asserts it is gone — entirely different
      // action from the test above, but the SIGNATURE used for comparison
      // never reaches this statement.
    });
  });
}
```

Real-world instances (same mechanism, different variants of "the divergence lives past the 2-statement window"):

1. `saropa_drift_advisor/test/schema_handler_test.dart:87,120,151` — three tests each with `final ctx = createTestContext(); final handler = SchemaHandler(ctx);` as statements 1–2 (identical every time), followed by a **third** statement, `mockQueryWithTables(tableColumns: {...})`, whose argument map is different per test. The divergence is in statement 3, past the signature's 2-statement cutoff.
2. `saropa_drift_advisor/test/handler_integration_test.dart:1487` (group `'edits batch endpoint'`) — three tests (`:1487`, and two more later in the same group) each start with `final executedSql = <String>[]; await DriftDebugServer.stop();` as statements 1–2, then diverge at statement 3 (`await startServer(writeQuery: (sql) async => executedSql.add(sql));` vs. a variant with a throwing `writeQuery` closure) and in the HTTP body/assertions that follow.
3. `saropa_drift_advisor/test/snapshot_handler_test.dart:147` (and 4 further sibling tests at `:135,160,178,193,212` — 5 tests total sharing the same 2-statement signature, well past the 3-test threshold) — every test starts with `await startServer(); await httpPost(serverPort!, '/api/snapshot');` as statements 1–2 (byte-identical), then diverges completely afterward: one test only checks the snapshot metadata, another deletes it, two more simulate row changes and assert diff counts. The rule's signature is built from exactly these first two statements and never sees the divergence.

**Frequency:** Always, whenever 3+ (or 4+, if the file already declares `setUp(`) tests in one `group()` share identical text for their first two non-trivial, non-assertion statements — regardless of what the tests do afterward.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — each test needs a distinct third-statement argument/closure or a distinct post-setup call sequence that `setUp()` cannot express without becoming parameterized (which `package:test`'s `setUp()` does not support) |
| **Actual** | `[prefer_setup_teardown] Duplicated test setup code. Use setUp()/tearDown().` reported on the first test in each group (`schema_handler_test.dart:87`, `handler_integration_test.dart:1487`, `snapshot_handler_test.dart:147`) |

---

## AST Context

```
CompilationUnit
  └─ FunctionDeclaration (main)
      └─ MethodInvocation (group('SnapshotHandler', ...))
          └─ FunctionExpression
              └─ BlockFunctionBody
                  ├─ MethodInvocation (test('GET ... returns null...', ...))         ← body[0..1] signature A (not flagged)
                  ├─ MethodInvocation (test('POST ... creates snapshot...', ...))    ← body[0..1] signature A (flagged here)
                  ├─ MethodInvocation (test('GET ... returns metadata...', ...))     ← body[0..1] signature A
                  ├─ MethodInvocation (test('DELETE ... clears snapshot', ...))      ← body[0..1] signature A
                  └─ MethodInvocation (test('compare with identical data...', ...))  ← body[0..1] signature A
```

All five `test(...)` calls' first two "body" statements (`await startServer();` + a bare `await httpPost(serverPort!, '/api/snapshot');`) are textually identical; everything each test does afterward — which is where they actually differ — is outside the AST nodes `_buildSetupSignature` ever visits.

---

## Root Cause

`PreferSetupTeardownRule._reportDuplicateSetup` (`testing_best_practices_rules.dart:3222-3254`) groups tests by `_signatureOf(testCall)` (`testing_best_practices_rules.dart:3264-3286`), which delegates to `_buildSetupSignature` (`testing_best_practices_rules.dart:3323-3342`):

```dart
String? _buildSetupSignature(NodeList<Statement> statements) {
  final preface = <String>[];
  final body = <Statement>[];
  for (final statement in statements) {
    if (_isSimpleLocalInit(statement)) {
      preface.add(_normalizedSetupStatement(statement));
      continue;
    }
    if (_isAssertionCall(statement)) {
      continue;
    }
    body.add(statement);
    if (body.length >= 2) {
      break;                                    // <-- root cause: hard stop at 2
    }
  }
  if (body.isEmpty) return null;
  return [...preface, ...body.map(_normalizedSetupStatement)].join(';');
}
```

The loop **stops collecting after two non-trivial, non-assertion statements** (`if (body.length >= 2) { break; }`) and the returned signature is the raw, whitespace-normalized `toSource()` text of just those first two statements (`_normalizedSetupStatement`, `testing_best_practices_rules.dart:3345-3347` — plain text join, no argument-value abstraction beyond the separate `_maskLiterals` masked-variant carve-out used only for *literal* arguments within those same first two statements). Any statement at index 2 or beyond — where all three real-world cases above put their actual per-test divergence (a differing map argument, a differing closure, a differing action/assertion sequence) — is **never read by the signature at all**, whether or not it differs across tests.

`_reportDuplicateSetup` (`testing_best_practices_rules.dart:3222-3254`) then counts exact matches of this truncated signature (`counts[sig]`) and only suppresses via the masked-literal-variant check (`maskedVariants`, `testing_best_practices_rules.dart:3232-3236,3243-3246`), which detects *the same statement differing only by a literal argument* — it has no way to detect "the tests are identical for 2 statements and diverge on statement 3+", because the divergent statement was already discarded by the `break` in `_buildSetupSignature` before `_reportDuplicateSetup` ever runs.

This is distinct from the two already-fixed false-positive classes in this rule's history (`plans/history/2026.04/2026.04.29/prefer_setup_teardown_false_positive_parameterized_sut_call.md`, `2026.06.13/prefer_setup_teardown_false_positive_per_test_parameterized_sut_construction.md`, `2026.06.10/prefer_setup_teardown_false_positive_per_test_arrange_and_pumpwidget.md`), all of which concern divergence *within* the first two statements (a literal argument, or a `WidgetTester` receiver) — not divergence in a statement the signature-builder never reaches.

---

## Suggested Fix

`_buildSetupSignature` needs to see enough of each test body to detect real per-test divergence before truncating, not just the first two statements. Two complementary options:

1. **Widen the window, then diff:** collect up to N (e.g. 4–5) non-trivial, non-assertion statements instead of 2, so a third/fourth-statement divergence is visible to the existing masked-literal-variant carve-out in `_reportDuplicateSetup` — this handles cases 1 and 3 above (differing map/closure argument, differing post-setup call) without new logic, just a larger window.
2. **Detect trailing divergence explicitly:** after the shared truncated-signature prefix matches for 3+ tests, look at the *next* statement (index `body.length` in the original, untruncated statement list) for each test; if it differs across the group (different method name, different argument shape, or one test simply has more/fewer statements after the shared prefix), treat the group as NOT extractable to a bare `setUp()` and suppress, since `package:test`'s `setUp()` cannot parameterize by test.

Option 2 is more targeted and avoids inflating the signature text (and therefore the false-negative risk of genuinely duplicated 4-statement setups going unflagged by 2 becoming 2-of-4 partial matches under option 1).

---

## Fixture Gap

Fixture: `example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart` (confirmed to exist). Existing fixture already covers the masked-literal parameterized-SUT carve-out and the `WidgetTester` receiver carve-out per the fix history above.

Missing NO-LINT cases:
1. **3+ tests share identical first-two-statement text, but a third statement passes a different literal/map argument to a shared helper** (this report's `schema_handler_test.dart` case) — expect NO lint.
2. **3+ tests share identical first-two-statement text, but the third statement passes a different closure** (this report's `handler_integration_test.dart` case) — expect NO lint.
3. **5 tests share identical first-two-statement text (`startServer()` + a bare setup POST), but diverge completely in every statement from the third onward** (this report's `snapshot_handler_test.dart` case, the strongest reproducer — no masked-literal involvement at all) — expect NO lint.
4. Retain existing coverage for the **true positive** this rule is meant to catch: 3+ tests whose entire body (not just the first two statements) is byte-for-byte duplicated, to make sure widening the window (option 1) or adding trailing-divergence detection (option 2) does not silence real duplication.

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Environment

- saropa_lints version: 16.2.1 (resolved; checkout at 16.3.0/HEAD, rule source unchanged)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings came from the `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `test/schema_handler_test.dart:87`, `test/handler_integration_test.dart:1487`, `test/snapshot_handler_test.dart:147`, scan report `reports/20260918/20260918_081229_findings.json`

---

## Finish Report (2026-09-18)

**Verdict: INVALID.** An initial pass implemented the report's suggested "trailing
divergence" carve-out, but an independent (Opus) review caught that the report's
central premise is wrong, and on re-reading the rule's purpose that review is
correct. That fix has been fully reverted; the rule is back to its original,
pre-report behavior.

**Why the premise is wrong:** the report treats *any* per-test divergence past the
shared 2-statement setup window as proof the group "cannot be collapsed to a bare
`setUp()`". That is not how `setUp()`/act-assert test structure works. `setUp()`
only needs to contain the statements that are genuinely identical across tests —
divergent statements simply stay in each test body, right after the part that moved.
Concretely, for the report's own `schema_handler_test.dart` case:

```dart
setUp(() {
  ctx = createTestContext();
  handler = SchemaHandler(ctx);
});

test('users table', () {
  mockQueryWithTables(tableColumns: {'users': [...]});
  // ...
});
```

This is a completely valid, idiomatic extraction — the differing
`mockQueryWithTables(...)` call is exactly the kind of per-test "arrange" statement
that normally lives in the test body, not in `setUp()`. The same is true of the
`snapshot_handler_test.dart` case (`startServer()` + a bare setup POST are the
genuinely shared fixture; what each test does afterward is the test's own
act/assert). Divergence *after* a shared prefix is the **normal shape of
`setUp()` extraction**, not evidence against it. The rule's existing masked-literal
carve-out already correctly identifies the one case where post-window-adjacent
divergence really does block extraction: when the divergence is a per-test literal
argument to the *same call inside the window* (parameterized SUT construction,
e.g. `AsyncSemaphoreUtils(1)` vs `(2)` vs `(3)`) — divergence *within or overlapping*
the shared prefix, not past it.

So the three "false positives" in the report were true positives: 3+ tests in each
group really do share identical, hoistable setup code, and the rule was correctly
telling the author to extract it. The `handler_integration_test.dart` case (closure
argument) is the same shape, and remains a true positive too — the two `startServer`
calls with a differing `writeQuery` closure are still an `await startServer();`
extractable to `setUp()`, with the differing closure argument moving into a per-test
`startServer(writeQuery: ...)` call inside each test body (i.e. the first shared
`startServer()` call, not the whole second call, is the actual duplication — the rule
flagging here is legitimate, and any real ergonomics complaint about `package:test`
having no per-test `setUp()` parameterization is a `package:test` limitation, not a
`saropa_lints` false positive).

**What was reverted:**
- `lib/src/rules/testing/testing_best_practices_rules.dart` — removed the
  `trailingByStatement` bucketing/suppression block from `_reportDuplicateSetup`,
  and removed the `_trailingStatementOf` helper and `_endOfBodyMarker` sentinel
  added in the earlier (incorrect) pass. The file is now byte-identical to
  pre-report `HEAD` for this rule (confirmed via `git diff`, no output).
- `example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart` — removed
  the three GOOD fixture cases added in the earlier pass
  (`_goodPreferSetupTeardownTrailingArgumentDivergence`,
  `_goodPreferSetupTeardownTrailingClosureDivergence`,
  `_goodPreferSetupTeardownTrailingFullDivergence`), which asserted NO lint for
  cases that should, correctly, still lint. File confirmed byte-identical to
  pre-report `HEAD` (`git diff`, no output).
- `CHANGELOG.md` — removed the `prefer_setup_teardown` bullet added under
  `## [16.4.0]` → `### Fixed` for the earlier (incorrect) fix. No other CHANGELOG
  edits were made.

**Test coverage replaced:** the earlier pass's 3 new tests in
`test/rules/testing/prefer_setup_teardown_test.dart` were vacuous — they only
grepped fixture text for the absence of `// expect_lint:`, and
`PreferSetupTeardownRule.applicableFileTypes => {FileType.test}` means the rule
never even analyzes files under `example/lib` in real analysis, so those assertions
proved nothing about rule behavior. They were replaced with 3 real tests using the
resolved-analyzer oracle (`runRuleResolved` from `test/support/resolved_rule_harness.dart`,
with `fileStem` ending in `_test` so the harness-written file satisfies
`FileType.test`'s path-based detection):
1. **DOES flag** — 3 tests sharing an identical 2-statement `Repo()`/`Svc(repo)`
   setup that diverge only in which method they call afterward (`sut.a()` /
   `.b()` / `.c()`) — confirms the normal "diverging act step" shape still
   correctly fires, i.e. confirms the earlier carve-out would have wrongly
   silenced it.
2. **DOES flag** — the report's own `schema_handler_test.dart` shape (shared
   `ctx`/`handler` construction, diverging `mockQueryWithTables(...)` argument) —
   confirms the report's central example is in fact a true positive.
3. **does NOT flag** — 3 tests whose very first statement differs per test
   (`_RepoA()` / `_RepoB()` / `_RepoC()`), i.e. no shared prefix at all — confirms
   the rule still correctly stays silent when there is genuinely nothing to
   extract.

**Files changed (this correction pass):**
- `lib/src/rules/testing/testing_best_practices_rules.dart` — reverted to
  pre-report `HEAD`.
- `example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart` —
  reverted to pre-report `HEAD`.
- `test/rules/testing/prefer_setup_teardown_test.dart` — vacuous fixture-text
  group replaced with 3 real `runRuleResolved` tests (see above); all other
  pre-existing tests in this file untouched.
- `CHANGELOG.md` — removed the one `prefer_setup_teardown` bullet from
  `## [16.4.0]` → `### Fixed` (the only CHANGELOG edit made).
- `bugs/prefer_setup_teardown_false_positive_signature_truncated_to_two_statements.md`
  — this report (moved to `plans/history/2026.09/2026.09.18/`, verdict corrected to
  INVALID).

**Tests:**
- `dart analyze lib/src/rules/testing/testing_best_practices_rules.dart
  example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart
  test/rules/testing/prefer_setup_teardown_test.dart` — No issues found.
- `dart test test/rules/testing/prefer_setup_teardown_test.dart` — all 11 tests
  pass, including the 3 new resolved-analyzer regression tests.
- `dart test test/rules/testing/testing_best_practices_rules_test.dart` still fails
  to *load* due to an unrelated, pre-existing compile error in
  `lib/src/rules/code_quality/code_quality_avoid_rules.dart:1663`
  (`ClassDeclaration.members` doesn't exist) — that file is being edited
  concurrently by another agent in this working tree and is untouched by this fix.

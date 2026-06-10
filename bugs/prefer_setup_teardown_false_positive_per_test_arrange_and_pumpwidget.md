# BUG: `prefer_setup_teardown` — Flags per-test arrange/`pumpWidget` that cannot move to `setUp()`

**Status: Open**

Created: 2026-06-10
Rule: `prefer_setup_teardown`
File: `lib/src/rules/testing/testing_best_practices_rules.dart` (line ~3096)
Severity: False positive
Rule version: v7

---

## Summary

The rule reports when ≥3 tests in a `group` share the same first 1–2 "setup" statements. But two very common shapes share an identical signature yet legitimately cannot be hoisted into `setUp()`:

1. **`tester.pumpWidget(...)` in `testWidgets`** — `WidgetTester` is only supplied to the `testWidgets` callback. `setUp()` receives no tester, so the pump call physically cannot live in `setUp()`.
2. **Per-group "arrange" data** — three tests that seed the SAME group-specific input (e.g. a 5-year-old DOB for a COPPA group) share a signature, but the value is intentionally per-group; the file already has a real `setUp()`/`tearDown()` for the genuinely shared fixture. Moving the arrange into a file-level `setUp()` would corrupt sibling groups that seed different data.

In both cases the rule fires even though the repeated lines are not extractable shared initialization.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_setup_teardown'" lib/src/rules/
# lib/src/rules/testing/testing_best_practices_rules.dart:3067:    'prefer_setup_teardown',

# Negative — NOT in sibling repo
grep -rn "'prefer_setup_teardown'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/testing/testing_best_practices_rules.dart:3067`
**Rule class:** `PreferSetupTeardownRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
// ---- Pattern 1: pumpWidget cannot move to setUp() ----
group('CommonFlipCard', () {
  testWidgets('renders front', (WidgetTester tester) async {   // LINT (FP)
    final controller = CommonFlipCardController();
    await tester.pumpWidget(buildTestApp(child: CommonFlipCard(controller: controller)));
    expect(controller.side, CardSide.front);
  });
  testWidgets('flip increments count', (WidgetTester tester) async {
    final controller = CommonFlipCardController();
    await tester.pumpWidget(buildTestApp(child: CommonFlipCard(controller: controller)));
    await controller.flip();
    expect(controller.state.flipCount, 1);
  });
  testWidgets('reset clears count', (WidgetTester tester) async {
    final controller = CommonFlipCardController();
    await tester.pumpWidget(buildTestApp(child: CommonFlipCard(controller: controller)));
    controller.reset();
    expect(controller.state.flipCount, 0);
  });
});

// ---- Pattern 2: per-group arrange; real setUp already present ----
setUp(() { cache = CacheHelper(); recorder = Recorder()..install(); });   // shared fixture IS extracted
tearDown(() { cache.tearDown(); recorder.uninstall(); });

group('COPPA short-circuit', () {
  test('under-13 returns false', () async {                    // LINT (FP)
    final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
    cache.seed(userDateOfBirth: fiveYearsAgo);
    expect(await init(), isFalse);
  });
  test('emits zero channel calls', () async {
    final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
    cache.seed(userDateOfBirth: fiveYearsAgo);
    await init();
    expect(recorder.calls, isEmpty);
  });
  test('leaves init flag false', () async {
    final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 5));
    cache.seed(userDateOfBirth: fiveYearsAgo);
    await init();
    expect(GoogleCrashlyticsUtils.isInitialized, isFalse);
  });
});

group('env-disabled short-circuit', () {  // sibling group seeds a DIFFERENT DOB
  test('...', () async {
    cache.seed(userDateOfBirth: DateTime(1990, 1, 1));  // adult — must NOT share setUp
    // ...
  });
});
```

Real sites:
- Pattern 1: `D:\src\contacts\test\lib\components\primitive\flip_card\common_flip_card_test.dart:84`
- Pattern 2: `D:\src\contacts\test\lib\service\google_analytics_api\google_crashlytics_utils_init_test.dart:85`

**Frequency:** Always, when ≥3 tests in one group share a `pumpWidget` shape, or share group-local arrange data.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `pumpWidget` is not hoistable; per-group arrange is intentionally not shared, and the real shared fixture is already in `setUp()`/`tearDown()`. |
| **Actual** | `[prefer_setup_teardown] Duplicated test setup code. Use setUp()/tearDown()...` reported on the first test of the group. |

---

## AST Context

```
MethodInvocation (group)
  └─ FunctionExpression → Block
      └─ ExpressionStatement
          └─ MethodInvocation (testWidgets / test)   ← node reported here
              └─ FunctionExpression (callback)
                  └─ Block
                      ├─ VariableDeclarationStatement (simple local init → "preface")
                      └─ ExpressionStatement: await tester.pumpWidget(...) / cache.seed(...)  ← "body" signature
```

---

## Root Cause

`testing_best_practices_rules.dart:3117-3186`. `_signatureOf` builds a signature from the first 1–2 non-assertion statements (`_buildSetupSignature`), prefixed by skipped simple local inits. `_reportDuplicateSetup` reports when a signature recurs ≥3 times in a group. The signature is purely **syntactic** (`statement.toSource()` normalized); it never asks whether the statement is *hoistable*:

1. It does not exclude `tester.pumpWidget(...)` / any expression that references the `testWidgets` callback's `WidgetTester` parameter. Such statements are bound to the per-test `tester` and cannot move to `setUp()` (which has no tester). They should never count toward the duplicate-setup threshold.
2. It does not consider that the matched statements may be the test's **arrange** step with group-specific inputs, while the file's genuinely shared fixture is already in `setUp()`/`tearDown()`. The rule has no signal for "shared setup already exists"; it counts the per-group arrange as if no `setUp()` were present.

Result: idiomatic widget tests (every `testWidgets` pumps a widget) and idiomatic AAA tests with per-group fixtures are flagged with no valid refactor available.

---

## Suggested Fix

In `_buildSetupSignature` / `_signatureOf`:

- **Exclude tester-bound statements.** If a candidate "body" statement's source references the `testWidgets` callback parameter (the `WidgetTester`, commonly `tester`) — e.g. `tester.pumpWidget`, `tester.pump`, `tester.pumpAndSettle`, `tester.tap` — return null (no signature). These are not hoistable to `setUp()`.
- **Down-weight pure arrange when a real `setUp()` exists.** If the enclosing file already declares a top-level `setUp(...)`, raise the threshold or skip when the only repeated statements are arrange/seed calls that differ by group — at minimum, do not report a group whose repeated statement is a method call on a fixture that `setUp()` already constructs (the fixture is shared; the per-test seed is intentionally not).

The first change alone removes the entire `testWidgets`/`pumpWidget` class of false positives.

---

## Fixture Gap

`example*/lib/testing/prefer_setup_teardown_fixture.dart` should include:

1. Three `test()`s sharing `final db = openDb(); db.reset();` (pure, hoistable) — expect LINT.
2. Three `testWidgets()`s each calling `await tester.pumpWidget(...)` — expect **NO** lint (tester-bound, not hoistable).
3. Three `test()`s in group A seeding one value and group B seeding another, with a file-level `setUp()` building the shared fixture — expect **NO** lint.

---

## Environment

- saropa_lints version: ^13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- custom_lint version: native analyzer plugin (analysis_server_plugin), not custom_lint
- Triggering project/files: `common_flip_card_test.dart:84`, `google_crashlytics_utils_init_test.dart:85`

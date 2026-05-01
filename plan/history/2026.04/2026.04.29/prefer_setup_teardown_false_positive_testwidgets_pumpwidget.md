# BUG: `prefer_setup_teardown` — False positive on `testWidgets` shared `tester.pumpWidget(...)` setup

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-29
Rule: `prefer_setup_teardown`
File: `lib/src/rules/testing/testing_best_practices_rules.dart` (around `_buildSetupSignature` / `_TestCallCollector`)
Severity: False positive (High — forces `// ignore:` workarounds across widget test files)
Rule version: v6 (and earlier) | Updated: v4.14.5

---

## Summary

The rule fires on `testWidgets` groups where 3+ tests start with an identical `await tester.pumpWidget(...)` invocation. The rule prescribes moving the duplicated setup to `setUp()`, but `tester` is the per-test parameter of the `testWidgets` callback — `setUp()` cannot access it. The prescribed fix is structurally impossible to apply.

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_setup_teardown'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/testing/testing_best_practices_rules.dart:3067:    'prefer_setup_teardown',

$ grep -rn "'prefer_setup_teardown'" D:/src/saropa_drift_advisor/lib/src/ D:/src/saropa_drift_advisor/extension/src/
# 0 matches — confirmed not in sibling repo
```

**Emitter registration:** `lib/src/rules/testing/testing_best_practices_rules.dart:3067`
**Rule class:** `PreferSetupTeardownRule` — registered in `lib/src/rules/all_rules.dart` and `lib/src/tiers.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart`

---

## Reproducer

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FacebookAuthFailureReason userMessage', () {
    testWidgets('cancelled returns localized message', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink())); // LINT (FP)
      await tester.pumpAndSettle();
      expect(true, isTrue);
    });

    testWidgets('network returns localized message', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink())); // duplicate signature
      await tester.pumpAndSettle();
      expect(true, isTrue);
    });

    testWidgets('timeout returns localized message', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink())); // duplicate signature → fires here
      await tester.pumpAndSettle();
      expect(true, isTrue);
    });
  });
}
```

The `await tester.pumpWidget(...)` line is identical across all three tests by source, so `_buildSetupSignature` collapses them onto the same key. With ≥3 matches the rule fires.

**Frequency:** Always — any `testWidgets` group with 3+ tests sharing identical `tester.pumpWidget` setup.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the prescribed fix (`setUp()`) cannot accept the per-test `tester` parameter, so the duplication cannot be hoisted as the rule suggests. |
| **Actual** | `[prefer_setup_teardown] Duplicated test setup code. Use setUp()/tearDown(). ...` reported on the first `testWidgets` in the group. |

---

## AST Context

```
CompilationUnit
  └─ FunctionDeclaration (main)
      └─ Block
          └─ ExpressionStatement
              └─ MethodInvocation (group "FacebookAuthFailureReason userMessage")
                  └─ FunctionExpression
                      └─ Block
                          ├─ MethodInvocation (testWidgets "cancelled ...")  ← reported here
                          │   └─ FunctionExpression(WidgetTester tester) async {
                          │       └─ AwaitExpression
                          │           └─ MethodInvocation (tester.pumpWidget(...))
                          │       ...
                          │   }
                          ├─ MethodInvocation (testWidgets "network ...")
                          │   └─ ... (same shape, same source as above)
                          └─ MethodInvocation (testWidgets "timeout ...")
                              └─ ... (same shape, same source as above)
```

`_TestCallCollector` collects both `test` and `testWidgets`. `_buildSetupSignature` reads the first 1–2 non-skipped statements of the callback body and treats `await tester.pumpWidget(...)` as ordinary setup code, even though `tester` is bound to the testWidgets callback parameter and is not visible to `setUp()`.

---

## Why this is wrong

1. **`tester` is per-test scoped.** It is the parameter of the `testWidgets` callback — `setUp()` runs *outside* that callback and has no `tester` in scope. The lint's prescribed refactor is a compile error.
2. **The lint cannot tell the difference between `test` and `testWidgets`.** `_TestCallCollector` accepts both, but only `test` callbacks have setup that can move to `setUp()`. Statements that reference `tester` should be excluded from the signature, OR `testWidgets` callbacks should be analyzed under different rules.
3. **Real impact.** Any flutter widget test file with 3+ tests that pump the same harness widget triggers this. The standard pattern in `D:\src\contacts` is:
   ```dart
   await tester.pumpWidget(buildTestApp(child: ...));
   await tester.pumpAndSettle();
   ```
   This is shared boilerplate that is structurally part of every widget test, not extractable to `setUp()`.

---

## Root Cause

### Hypothesis A: `_buildSetupSignature` does not exclude statements that reference the testWidgets callback parameter

`_buildSetupSignature` filters only by `_isSimpleLocalInit` and `_isAssertionCall`. It has no awareness of:
- `MethodInvocation` whose target chain begins with the enclosing `testWidgets` callback's parameter (`tester`)
- `AwaitExpression` wrapping such calls

Any statement that references `tester` (`tester.pumpWidget`, `tester.pump`, `tester.pumpAndSettle`, `tester.tap`, `tester.enterText`, …) cannot be hoisted to `setUp()` because that parameter does not exist there. These should be excluded from the signature.

### Hypothesis B: `_TestCallCollector` treats `test` and `testWidgets` identically

```dart
if (name == 'test' || name == 'testWidgets') {
  testCalls.add(node);
}
```

A simpler narrower fix: exclude `testWidgets` from collection entirely if the rule cannot meaningfully recommend `setUp()` for tester-bound work. This is broad — it would also miss real shared init like `late MyService service;` inside testWidgets groups — but it would close the FP without analyzing parameter references.

The cleaner fix is Hypothesis A: keep `testWidgets` collection, but exclude tester-parameter-referencing statements from the signature.

---

## Suggested Fix

In `_buildSetupSignature` (or a new helper called before it), add a filter that excludes any statement whose expression tree references the enclosing `testWidgets` callback's first parameter (typically named `tester`, but should be resolved by element, not by name). Pseudocode:

```dart
String? _signatureOf(MethodInvocation testCall) {
  final callback = _getTestCallback(testCall);
  if (callback == null) return null;
  final body = callback.body;
  if (body is! BlockFunctionBody) return null;

  // For testWidgets, identify the tester parameter element so we can
  // exclude statements that reference it from the setup signature.
  final ParameterElement? testerParam = testCall.methodName.name == 'testWidgets'
      ? callback.parameters?.parameters.firstOrNull?.declaredElement as ParameterElement?
      : null;

  final statements = body.block.statements;
  if (statements.isEmpty) return null;

  return _buildSetupSignature(statements, testerParam);
}

String? _buildSetupSignature(NodeList<Statement> statements, ParameterElement? testerParam) {
  final meaningful = statements
      .where((s) =>
          !_isSimpleLocalInit(s) &&
          !_isAssertionCall(s) &&
          !_referencesParameter(s, testerParam))
      .take(2)
      .toList();
  if (meaningful.isEmpty) return null;
  return meaningful
      .map((s) => s.toSource().replaceAll(RegExp(r'\s+'), ' '))
      .join(';');
}

bool _referencesParameter(Statement stmt, ParameterElement? param) {
  if (param == null) return false;
  final visitor = _ParameterRefVisitor(param);
  stmt.accept(visitor);
  return visitor.found;
}

class _ParameterRefVisitor extends RecursiveAstVisitor<void> {
  _ParameterRefVisitor(this.target);
  final ParameterElement target;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.staticElement == target) found = true;
    super.visitSimpleIdentifier(node);
  }
}
```

This preserves detection of genuine duplication (e.g. `final db = AppDatabase.forTesting(...);` inside `testWidgets`) while removing the FP for tester-bound work.

---

## Fixture Gap

The fixture at `example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart` should include:

1. **`testWidgets` group with 3+ tests sharing `tester.pumpWidget(...)`** — expect NO LINT
2. **`testWidgets` group with 3+ tests sharing `final svc = MyService();` (no tester reference)** — expect LINT (real duplication, hoist to `setUp()`)
3. **Mixed group: 2 tests with shared `tester.pumpWidget`, 1 with shared `final svc = MyService();`** — expect NO LINT (insufficient matches once tester refs filtered out)

---

## Affected sites in `D:\src\contacts`

- `test/lib/components/contact/reaction/contact_reaction_widget_test.dart:197` — `ContactReactionGridSheet` group, 4 testWidgets sharing `tester.pumpWidget(buildTestApp(child: Builder(...)))` then `tester.tap` + `tester.pumpAndSettle`.
- `test/lib/models/authentication/facebook_auth_result_test.dart:30` — `FacebookAuthFailureReason userMessage` group, 9 testWidgets sharing `tester.pumpWidget(buildTestApp(...))` + `tester.pumpAndSettle()`.

---

## Environment

- saropa_lints version: 4.14.5 (rule v6 at time of report)
- Dart SDK version: per `D:\src\contacts\pubspec.yaml`
- custom_lint version: native analyzer plugin (analysis_server_plugin)
- Triggering project/file: `D:\src\contacts`

---

## Workaround (until fix lands)

`// ignore: prefer_setup_teardown` immediately above the first flagged `testWidgets(` call, with an explanatory comment one line above the ignore directive referencing this report.

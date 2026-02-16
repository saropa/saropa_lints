# `prefer_setup_teardown` false positive: treats `expect()` assertions as setup code

## Status: FIXED (v4.14.5, rule v6)

## Fix Summary

Two changes to `PreferSetupTeardownRule` in `testing_best_practices_rules.dart`:
1. **Added `_isAssertionCall()` filter** — `_buildSetupSignature()` now excludes `expect`, `expectLater`, `await expectLater`, `fail`, `verify*` and all `expectAsync0..6` from setup signatures.
2. **Scoped counting per `group()`** — `_findEnclosingGroup()` walks the AST to find the nearest enclosing `group()` call. Signatures are only compared within the same group scope.

## Problem

The `prefer_setup_teardown` rule misidentifies `expect()` assertions as duplicated setup code. When 3+ tests in a file contain similar `expect()` calls as their only meaningful statement, the rule fires and suggests moving them to `setUp()` — which is nonsensical because `expect()` is an assertion, not initialization.

### Example: documentation-style tests with `expect(true, isTrue)`

```dart
group('Prompt Conditions (documented behavior)', () {
  test('should NOT show prompt if user is logged in', () {
    // Per plan: This feature is for pre-login engagement only
    expect(true, isTrue, reason: 'Verified via code review');
  });

  test('should NOT show prompt during cooldown period', () {
    // If _lastCheckTime is within 24 hours, return false
    expect(true, isTrue, reason: 'Verified via code review');
  });

  test('should NOT show prompt after max attempts reached', () {
    // Queries ActivityType.NetworkCountPromptShown count
    expect(true, isTrue, reason: 'Verified via code review');
  });
});
```

The rule reports on the first test:

```
[prefer_setup_teardown] Duplicated test setup code. Use setUp()/tearDown().
```

Moving `expect()` to `setUp()` makes no sense — assertions are the purpose of the test, not setup.

## Affected Rule

**File:** `lib/src/rules/testing_best_practices_rules.dart` lines 2966–3097

**Root cause** — `_buildSetupSignature()` (lines 3052–3060):

```dart
String? _buildSetupSignature(NodeList<Statement> statements) {
  final meaningful =
      statements.where((s) => !_isSimpleLocalInit(s)).take(2).toList();
  if (meaningful.isEmpty) return null;

  return meaningful
      .map((s) => s.toSource().replaceAll(RegExp(r'\s+'), ' '))
      .join(';');
}
```

The method considers **any statement that isn't a simple local variable initialization** as "setup code." It has no awareness that `expect()` (and other assertion functions) are test assertions, not setup. An `expect()` call passes the `!_isSimpleLocalInit(s)` filter because it's an `ExpressionStatement` containing a `MethodInvocation`, not a `VariableDeclarationStatement`.

The threshold check (lines 3023–3024) then counts 3+ identical signatures and fires the diagnostic.

## Why this is wrong

1. **`expect()` is an assertion, not setup.** The rule's intent is to extract repeated *initialization* into `setUp()`. Assertions belong inside individual tests — they are the test's raison d'etre.

2. **The suggested fix is impossible to apply correctly.** Moving `expect(true, isTrue)` to `setUp()` would run the assertion before every test as a precondition, fundamentally changing the test semantics. It would also leave the individual `test()` bodies empty.

3. **This pattern is legitimate.** Documentation-style tests that verify design intent via code review (common when the real logic depends on auth state, databases, or other non-unit-testable infrastructure) use `expect(true, isTrue, reason: '...')` as a deliberate pattern.

4. **The false positive extends beyond `expect(true, isTrue)`.** Any repeated assertion pattern across 3+ tests would trigger this — for example, multiple tests that each call `expect(result, isNull)` or `expect(widget, findsOneWidget)`.

## Broader scope: all assertion functions

The same false positive would occur with any repeated test assertion function, including:

| Function | Package |
|----------|---------|
| `expect()` | `flutter_test` / `test` |
| `expectLater()` | `flutter_test` / `test` |
| `expectAsync0..6()` | `test` |
| `fail()` | `test` |
| `verify()` | `mockito` |
| `verifyInOrder()` | `mockito` |
| `verifyNever()` | `mockito` |
| `verifyNoMoreInteractions()` | `mockito` |
| `verifyZeroInteractions()` | `mockito` |

## Suggested fix

Exclude known assertion/verification functions from the setup signature. These calls are test body, not setup:

```dart
/// Returns true if the statement is a test assertion that should never
/// be considered setup code.
bool _isAssertionCall(Statement statement) {
  if (statement is! ExpressionStatement) return false;
  final expression = statement.expression;
  if (expression is! MethodInvocation) return false;

  const Set<String> assertionFunctions = {
    'expect',
    'expectLater',
    'expectAsync0', 'expectAsync1', 'expectAsync2',
    'expectAsync3', 'expectAsync4', 'expectAsync5', 'expectAsync6',
    'fail',
    'verify',
    'verifyInOrder',
    'verifyNever',
    'verifyNoMoreInteractions',
    'verifyZeroInteractions',
  };

  return assertionFunctions.contains(expression.methodName.name);
}

String? _buildSetupSignature(NodeList<Statement> statements) {
  final meaningful = statements
      .where((s) => !_isSimpleLocalInit(s) && !_isAssertionCall(s))
      .take(2)
      .toList();
  if (meaningful.isEmpty) return null;

  return meaningful
      .map((s) => s.toSource().replaceAll(RegExp(r'\s+'), ' '))
      .join(';');
}
```

This preserves the rule's intended behavior (detecting duplicated object construction, method calls, mock setup, etc.) while excluding statements that are inherently per-test.

## Secondary issue: cross-group matching

The rule collects **all** `test()` calls across the entire file via `_TestCallCollector`, which is a `RecursiveAstVisitor`. It does not scope matching to within a single `group()`. This means tests in completely unrelated groups contribute to the same signature count.

In the triggering file, the `expect(true, isTrue, reason: 'Verified via code review')` pattern appears across 5 different groups (`Prompt Conditions`, `Activity Logging`, `Cache Behavior`, `Toast Configuration`, `Import Activity Types`, `Error Handling`). Each group documents a different aspect of the class. Even if the repeated pattern were genuine setup code, it wouldn't make sense to extract it to a file-level `setUp()` shared across unrelated groups.

Consider scoping signature counting to within a single `group()` block, or at minimum requiring that the 3+ matches occur within the same group.

## Reproduction

Any test file where 3+ tests contain an `expect()` call as their first meaningful statement with identical arguments:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Example', () {
    test('case A', () {
      expect(true, isTrue, reason: 'Documented behavior');
    });

    test('case B', () {
      expect(true, isTrue, reason: 'Documented behavior');
    });

    test('case C', () {
      // This third test triggers the rule
      expect(true, isTrue, reason: 'Documented behavior');
    });
  });
}
```

## Environment

- **saropa_lints version:** 4.14.5
- **Trigger project:** `D:\src\contacts`
- **File affected:**
  - `test/lib/utils/network/network_count_prompt_utils_test.dart:97` — first match reported
  - 17 tests in the file use `expect(true, isTrue, reason: 'Verified via code review')` across 5 groups

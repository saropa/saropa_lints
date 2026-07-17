# Fix: `prefer_notifier_over_state` `.toSource().contains()` anti-pattern

The `_StateProviderVisitor` in `riverpod_rules.dart` used `initializer.toSource().contains('StateProvider')` to detect `StateProvider(...)` declarations. This substring match on serialized AST source is the documented #1 source of false positives across saropa_lints rules, and the anti-pattern detection integrity test (`test/integrity/anti_pattern_detection_test.dart`) correctly flagged it as a new violation against an empty baseline.

## Finish Report (2026-07-17)

### Root cause

The visitor serialized the entire initializer expression to a string and searched for the substring `StateProvider`. Any expression whose source text happened to contain that substring (e.g., a variable named `myStateProviderConfig`, a comment, or a nested generic) would be falsely collected as a StateProvider declaration.

### Fix

Replaced the `.toSource().contains('StateProvider')` call with a static `_isStateProviderCreation(Expression)` method that checks the AST node type directly:

- `InstanceCreationExpression` — checks `constructorName.type.name.lexeme == 'StateProvider'`
- `MethodInvocation` — checks `target` is a `SimpleIdentifier` named `StateProvider` AND `methodName` is in `{'autoDispose', 'family'}` (the known Riverpod factory methods). Without the method-name restriction, any `StateProvider.somethingElse()` call would false-positive.
- `FunctionExpressionInvocation` — checks `function` is a `SimpleIdentifier` named `StateProvider` (defensive branch for unresolved-type edge case)

### Hardening (follow-up)

- **Tightened MethodInvocation branch**: the initial fix accepted any method name on `StateProvider.*()`. Now restricted to `{'autoDispose', 'family'}` via a `_stateProviderFactories` constant, preventing false positives from hypothetical unrelated static methods.
- **Extended fixture**: added `StateProvider.autoDispose(...)` (BAD, over-mutated) and a `myStateProviderConfig` false-positive decoy (GOOD, must not trigger) to pin the detection branches and guard against regression.
- **Mock updated**: `StateProvider` in `flutter_mocks.dart` gained `autoDispose` and `family` static factory methods so the fixture compiles.
- **`.name2` deprecation**: investigated — `.name.lexeme` is used 1398 times across all rule files with zero `.name2` usage. Not a current concern; `name2` was an analyzer migration path that this codebase hasn't adopted.

### Verification

- `dart test test/integrity/anti_pattern_detection_test.dart` — all 4 tests pass
- `dart test test/rules/packages/riverpod_rules_test.dart` — all tests pass
- CHANGELOG updated

### Files changed

- `lib/src/rules/packages/riverpod_rules.dart` — replaced anti-pattern with AST-based check, tightened MethodInvocation branch
- `example/lib/state_management/prefer_notifier_over_state_fixture.dart` — added autoDispose and false-positive decoy cases
- `example/lib/flutter_mocks.dart` — added `autoDispose`/`family` factory methods to `StateProvider` mock
- `CHANGELOG.md` — updated Fixed entry

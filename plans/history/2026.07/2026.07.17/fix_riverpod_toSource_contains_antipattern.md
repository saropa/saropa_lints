# Fix: `prefer_notifier_over_state` `.toSource().contains()` anti-pattern

The `_StateProviderVisitor` in `riverpod_rules.dart` used `initializer.toSource().contains('StateProvider')` to detect `StateProvider(...)` declarations. This substring match on serialized AST source is the documented #1 source of false positives across saropa_lints rules, and the anti-pattern detection integrity test (`test/integrity/anti_pattern_detection_test.dart`) correctly flagged it as a new violation against an empty baseline.

## Finish Report (2026-07-17)

### Root cause

The visitor serialized the entire initializer expression to a string and searched for the substring `StateProvider`. Any expression whose source text happened to contain that substring (e.g., a variable named `myStateProviderConfig`, a comment, or a nested generic) would be falsely collected as a StateProvider declaration.

### Fix

Replaced the `.toSource().contains('StateProvider')` call with a static `_isStateProviderCreation(Expression)` method that checks the AST node type directly:

- `InstanceCreationExpression` — checks `constructorName.type.name.lexeme == 'StateProvider'`
- `MethodInvocation` — checks `target` is a `SimpleIdentifier` named `StateProvider` (covers `StateProvider.autoDispose(...)`)
- `FunctionExpressionInvocation` — checks `function` is a `SimpleIdentifier` named `StateProvider`

### Verification

- `dart test test/integrity/anti_pattern_detection_test.dart` — all 4 tests pass (was failing on "NEW violations, file not in baseline")
- `dart test test/rules/packages/riverpod_rules_test.dart` — all tests pass
- CHANGELOG updated

### Files changed

- `lib/src/rules/packages/riverpod_rules.dart` — replaced anti-pattern with AST-based check
- `CHANGELOG.md` — added Fixed entry

# PROPOSAL: Avoid Dynamic Calls

**Status: Implemented**

Created: 2026-09-02

## Summary

Flags a method call, property access, or operator invocation performed on a receiver whose static type is `dynamic`, since it bypasses the analyzer's static type checking entirely.

## Existing Coverage

`lib/src/rules/data/type_safety_rules.dart` has `AvoidDynamicJsonAccessRule` and `AvoidDynamicJsonChainsRule`, but both are scoped narrowly to JSON decode results (`jsonDecode`/`Map<String, dynamic>` chains). This proposal is a genuine, broader extension: it targets *any* dynamically-typed receiver (a `dynamic`-typed local, field, or parameter — not just JSON), which is a strictly larger and more general class of unsafe calls.

## Motivation

A call on a `dynamic` receiver defers all member-resolution and type-checking to runtime. Typos in method names, wrong argument counts, and type mismatches all compile silently and only surface as a `NoSuchMethodError` in production. This defeats the entire point of Dart's static type system for that call site and is a frequent source of crashes that unit tests miss when they don't exercise every code path.

## Detection / Behavior

Triggers when a `MethodInvocation`, `PropertyAccess`, `PrefixedIdentifier`, or `BinaryExpression`/`IndexExpression` operator resolves its target/operand to the `dynamic` static type (via `usesTypeResolution`), excluding intentional dynamic use inside `noSuchMethod` overrides or explicitly annotated `// ignore:` sites.

```dart
// BAD
void process(dynamic data) {
  data.calculateTotal(); // no compile-time check this method exists
}

// GOOD
void process(Invoice data) {
  data.calculateTotal(); // statically verified
}
// or, if the dynamic type is unavoidable (e.g. plugin bridge):
void process(dynamic data) {
  (data as Invoice).calculateTotal();
}
```

## Quick Fix

None — manual refactor required. The fix depends on whether a concrete type can be introduced (change the parameter/variable type) or whether an explicit `as` cast with a runtime type check is the only option (e.g. platform-channel or reflection boundaries).

## Alternatives Considered

Limiting the rule to function parameters only (not locals/fields) was considered to reduce noise from legitimately dynamic interop code, but the general receiver-type check is more valuable and consistent with the existing narrower JSON-specific rules, which this proposal complements rather than replaces.

## Finish Report (2026-09-04)

### Issues

- **Cascade sections never flagged.** For `dynamicValue..foo()..bar()`, the individual `MethodInvocation`/`PropertyAccess`/`IndexExpression` nodes inside a `CascadeExpression`'s sections have `target == null` (the receiver is implicit). `_hasDynamicStaticType(node.target)` returns `false` on a `null` target, so no diagnostic fires even though every cascaded call dispatches on the dynamic receiver exactly like the covered non-cascade form. `context.addCascadeExpression` exists in `lib/src/native/saropa_context.dart` (line 677) but is unused by this rule — false negative.
- **Compound assignment operators unflagged.** `dynamicValue += 1;` invokes the dynamic `+` operator the same way `dynamicValue + 1` does (which IS covered via `addBinaryExpression`, lines 137-143), but compound assignment is an `AssignmentExpression`, not a `BinaryExpression`, and `runWithReporter` never calls `context.addAssignmentExpression` (hook exists at line 652, unused). False negative for `+=`, `-=`, `*=`, etc.
- **Prefix/postfix operators unflagged.** `dynamicValue++`, `--dynamicValue`, unary `-dynamicValue`, `~dynamicValue` resolve through `PrefixExpression`/`PostfixExpression` and invoke dynamic operator methods, but neither `context.addPrefixExpression` nor `context.addPostfixExpression` (both exist in `saropa_context.dart`, lines 953/958) is registered. False negative, same risk class as the already-covered `BinaryExpression` case.
- **Calling a dynamic value as a function unflagged.** `dynamic fn = ...; fn();` is a `FunctionExpressionInvocation`, not a `MethodInvocation` (no member name — synthetic `call()` dispatch). `context.addFunctionExpressionInvocation` exists (line 821) but is unused. This is an unchecked dynamic dispatch identical in kind to the one the rule already targets for named methods.

### Concerns

- `test/rules/data/avoid_dynamic_calls_test.dart` never executes the rule against `avoid_dynamic_calls_fixture.dart`. It only asserts rule metadata (code name, message length, correction message non-null) and that the fixture file exists on disk — the `// expect_lint:` markers in the fixture are not verified by `dart test`. Per project history this is a known "silent rule" risk class: a regression that breaks detection (e.g. an accidental visitor removal) would not fail CI here, only a manual `scan` CLI run or accuracy tooling would catch it.
- `_isInsideNoSuchMethod` (lines 158-162) exempts the ENTIRE body of any method literally named `noSuchMethod`, not just calls that touch the `Invocation` parameter. A genuinely unrelated typo'd dynamic call written inside a large `noSuchMethod` override body would be silently suppressed. Low real-world impact (these overrides are typically short) but the exemption is broader than its stated justification ("the call ... is the whole point of the override").
- No fixture/test coverage exists for null-aware forms (`dynamicValue?.foo()`, `dynamicValue?[0]`) to lock in that the rule still fires through `?.`/`?[]` (it should, since null-awareness doesn't change the target's static type, but this is currently unverified by any test).
- The four false negatives above have no fixture cases either, so once fixed there is nothing pinning them against future regression.

### Opportunities

- Close all four false negatives with the same two helpers already on the class (`_hasDynamicStaticType`, `_isInsideNoSuchMethod`) — no new abstractions needed, just four more `context.add*` registrations in `runWithReporter` mirroring the existing five.
- For cascades, check `node.target`'s static type on the `CascadeExpression` itself and report once per cascade (not once per section) to avoid duplicate diagnostics on `x..a()..b()..c()`.
- Reuse `_operatorInvocationTokens` (lines 95-99) for the compound-assignment/prefix/postfix case by mapping compound tokens to their base operator (e.g. `+=` → `+`), keeping the "meaningful operator, not `==`/`&&`/`||`" policy consistent across all four operator-shaped call sites instead of re-deriving it.

### Recommendations

1. **High** — Add `context.addFunctionExpressionInvocation` and `context.addAssignmentExpression` (compound assignments only; exclude plain `=` and `??=`, which don't dispatch through the receiver's own operator) handlers. These close the two most user-visible false negatives and match the rule's own stated scope ("ANY dynamically-typed receiver").
2. **Medium** — Add `context.addPrefixExpression`/`context.addPostfixExpression` handling for `++`/`--`/unary operators, for parity with the already-covered `BinaryExpression` case.
3. **Medium** — Add `context.addCascadeExpression` support so `dynamicValue..foo()` is caught; add a fixture case.
4. **Low** — Add fixture cases + `expect_lint` coverage for cascade, compound assignment, prefix/postfix, function-expression-invocation (once implemented above), and null-aware access (`?.`/`?[]`) as GOOD/BAD contrasts, so the fixes are regression-tested.
5. **Low** — Leave `_isInsideNoSuchMethod` as-is; it's a documented, deliberate simplicity trade-off with low real-world impact. Revisit only if a false negative inside a `noSuchMethod` body is actually reported.

# PROPOSAL: Avoid Dynamic Calls

**Status: Open**

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

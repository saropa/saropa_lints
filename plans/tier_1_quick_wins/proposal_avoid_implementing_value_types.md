# PROPOSAL: Avoid Implementing Value Types

**Status: Implemented**

Created: 2026-09-02

## Summary

Flags a class that uses `implements` (rather than `extends`) on a known value type — a class whose identity is defined by its `==`/`hashCode` contract (e.g. `Equatable`, `String`, `int`, or any class already flagged as a value type by this package's Equatable rules).

## Existing Coverage

No existing rule in `lib/src/rules/` addresses `implements` vs `extends` for value types. `equatable_rules.dart` has rules about correct `Equatable` usage (`ExtendEquatableRule`, `PreferEquatableMixinRule`) but nothing about the `implements`-breaks-inheritance-of-`==` failure mode. No duplicate.

## Motivation

`implements` on a class does not inherit its implementation — only its interface (member signatures) are enforced. A class that `implements` a value type such as `Equatable` must redeclare `props`, `==`, and `hashCode` from scratch; if it doesn't (or gets it subtly wrong), instances silently fall back to identity equality (`==` compares references), breaking every collection, `Set`, `Map` key, or equality-based test that assumes value semantics. This is a common and hard-to-spot Dart footgun because the code compiles cleanly and only misbehaves at runtime.

## Detection / Behavior

Triggers when a class's `implements` clause names a type known to define value equality (the `equatable` package's `Equatable`/`EquatableMixin`, or any class in the same library that itself extends/mixes in one of those), and the implementing class does not also override `==` and `hashCode` itself.

```dart
// BAD
class UserId implements Equatable {
  UserId(this.value);
  final String value;
  // == and hashCode are NOT inherited — reference equality applies.
}

// GOOD
class UserId extends Equatable {
  const UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
```

## Quick Fix

Suggest changing `implements` to `extends` (or `with` for a mixin) when the target type's constructor is compatible. None — manual refactor required when the class already extends another type (Dart is single-inheritance), since the fix then involves composition or explicit `==`/`hashCode` overrides.

## Alternatives Considered

Broadening to all value types (not just Equatable-based ones) via `usesTypeResolution` checks against the SDK's own value types (`Duration`, `Uri`, etc.) was considered but deferred — the Equatable-based case is the dominant real-world occurrence in Flutter codebases and keeps the first version's false-positive rate low.

## Finish Report (2026-09-04)

### Issues

1. **False positive: inherited (not manually-declared) equality is not recognized** — `_declaresOwnEqualityContract` (rules file, lines 173-185) only scans `node.bodyMembers` for a directly-declared `operator ==` and `hashCode` getter. It never checks the class's own `extendsClause`/`withClause` for an *already-correct* Equatable-based implementation. Concretely:
   ```dart
   abstract class ValueObject implements Equatable {}

   class Money with EquatableMixin implements ValueObject {
     Money(this.cents);
     final int cents;
     @override
     List<Object?> get props => [cents];
   }
   ```
   `Money` gets correct value equality from `EquatableMixin` via `with`, and separately `implements ValueObject` (an abstract marker/contract interface) purely for typing — a real Dart 3 "interface class" idiom (public contract via `implements`, behavior via `with`/`extends`). `_implementsValueEqualityType` walks `ValueObject`'s supertypes, finds `Equatable`, returns true. `_declaresOwnEqualityContract` finds no `==`/`hashCode` written directly in `Money`'s body (they come from the mixin) and returns false. The rule fires on correct code. The same false positive occurs for `class Foo extends Equatable implements Bar` where `Bar` itself extends/implements `Equatable` — `Foo`'s own equality already comes from `extends Equatable`, but the check only inspects the body, not the extends chain.

2. **Test suite doesn't exercise the rule's own headline feature** — the resolved-supertype walk (`_implementsValueEqualityType`, lines 152-167, iterating `resolved.element.allSupertypes`) is the one piece of logic in this rule that goes beyond simple name matching, and it is only exercised by the fixture's `OrderId`/`BaseId` pair (`example/lib/packages/avoid_implementing_value_types_fixture.dart:44-56`), which is not run as part of `dart test`. The unit tests (`test/rules/packages/avoid_implementing_value_types_test.dart`) cover only direct-name matches (`implements Equatable` / `implements EquatableMixin` / `implements Comparable`). If the `allSupertypes` walk regresses (e.g. a future analyzer upgrade changes `InterfaceType.element` semantics), no unit test would catch it.

### Concerns

1. **Rule is not in `equatablePackageRules`** (`lib/src/tiers.dart:3880-3895`) even though it is exclusively about `Equatable`/`EquatableMixin` and lives in `lib/src/rules/packages/`. It is registered only in `comprehensiveOnlyRules` (`lib/src/tiers.dart:3290`) and mapped to the generic `'packages'` category in `rule_category_map.dart:379`. This may be intentional (the rule matches by lexeme even when `equatable` isn't a real dependency, so it doesn't need dependency-gating), but nothing in the code or proposal documents that reasoning — a future maintainer grouping "all Equatable rules" by that tier set will silently miss this one.
2. **Test file's own docstring is stale**: lines 8-14 of the test say the rule "is not yet wired into the global tier registry" — but it is fully wired (`lib/saropa_lints.dart:2930`, `lib/src/tiers.dart:3290`, `lib/src/rules/all_rules.dart:215`). Harmless, but misleading to the next person reading the test.
3. **Narrow AST coverage**: detection only visits `ClassDeclaration` (via `context.addClassDeclaration`). An `enum Foo implements Equatable { ... }` (legal since Dart 2.17 enhanced enums) or a `mixin` declaring `implements` against an interface built on Equatable would silently skip detection. Low real-world frequency, but worth a one-line doc note if not going to be fixed.
4. **`_declaresOwnEqualityContract` requires exact getter/operator shape** (`member.isOperator && name == '=='`, `member.isGetter && name == 'hashCode'`) — an abstract redeclaration (`bool operator ==(Object other);` with no body, e.g. in an abstract class re-asserting the contract) would count as "declared" even though it provides no actual behavior. Edge case, not covered by any test.

### Opportunities

1. Fixing Issue #1 only requires extending `_declaresOwnEqualityContract` (or a sibling helper) to also walk `node.extendsClause?.superclass.type` and `node.withClause?.mixinTypes` through `allSupertypes`, checking whether any of them is a known value-equality type — reusing the exact same `_knownValueEqualityNames` matching logic already written for `_implementsValueEqualityType`, rather than a second bespoke check. The two methods could share one `_resolvesToValueEqualityType(DartType?)` helper.
2. Add the two missing fixture patterns (mixin-provided equality + redundant `implements` of an already-Equatable-derived marker interface, and extends-Equatable + implements-derived-interface) as new GOOD near-miss cases once Issue #1 is fixed, and add matching unit tests for both plus the currently-untested `OrderId`/`BaseId` indirect-supertype case.

### Recommendations

1. **High priority** — fix Issue #1 (extends/with-provided equality is not recognized) before this rule sees wider default-tier exposure; it is a plausible false positive against a real Dart 3 idiom (interface-contract classes) and the rule's severity is `LintImpact.error`, so a false hit is maximally disruptive.
2. **Medium priority** — add a unit test for the `OrderId extends BaseId (indirect supertype)` case already demonstrated in the fixture, so the `allSupertypes` walk has direct regression coverage.
3. **Low priority** — correct the stale "not yet wired" comment in the test file's docstring; document (in a code comment) why this rule is excluded from `equatablePackageRules`, or add it if the exclusion was accidental.
4. **Low priority** — note the enum/mixin `implements` gap as a known limitation in the rule's dartdoc, or extend `context.addClassDeclaration` coverage to enums if it's cheap to do given the existing infrastructure.

// ignore_for_file: unused_element

/// Fixtures for avoid_implementing_value_types_extended.
library;

// Deliberately not importing package:equatable here (fixtures avoid adding
// external dependencies). The rule matches a resolved element from
// `package:equatable/` outright, and otherwise accepts an element named
// `Equatable`/`EquatableMixin` ONLY when it structurally corroborates the
// contract by declaring a `props` getter. These stand-ins do declare
// `props`, so detection still fires here without a real dependency (see
// the rule test's harness comment for the same rationale).
abstract class Equatable {
  List<Object?> get props;
}

mixin EquatableMixin {
  List<Object?> get props;
}

// =============================================================================
// BAD: implements a value-equality type without redeclaring == / hashCode
// =============================================================================

// expect_lint: avoid_implementing_value_types_extended
class UserId implements Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => <Object?>[value];
  // == and hashCode are NOT inherited via `implements` — reference equality
  // silently applies, so this class breaks Set/Map-key/dedup semantics.
}

// expect_lint: avoid_implementing_value_types_extended
class Money implements EquatableMixin {
  Money(this.cents);
  final int cents;

  @override
  List<Object?> get props => <Object?>[cents];
}

// Indirect case: OrderId doesn't name Equatable directly, but its supertype
// (extends Equatable) does — the rule walks resolved supertypes to catch
// this. Requires a resolved analysis context to fire (see scan --resolve).
// expect_lint: avoid_implementing_value_types_extended
class OrderId implements BaseId {
  OrderId(this.raw);
  final String raw;

  @override
  List<Object?> get props => <Object?>[raw];
}

abstract class BaseId extends Equatable {}

// =============================================================================
// GOOD: extends Equatable instead of implementing it
// =============================================================================

class AccountId extends Equatable {
  AccountId(this.value);
  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

// =============================================================================
// GOOD near-miss: implements Equatable but redeclares == and hashCode
// =============================================================================

class SessionId implements Equatable {
  SessionId(this.value);
  final String value;

  @override
  List<Object?> get props => <Object?>[value];

  @override
  bool operator ==(Object other) => other is SessionId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

// =============================================================================
// GOOD near-miss: implements an unrelated interface, not a value type
// =============================================================================

class DeviceId implements Comparable<DeviceId> {
  DeviceId(this.value);
  final String value;

  @override
  int compareTo(DeviceId other) => value.compareTo(other.value);
}

// =============================================================================
// GOOD: Dart 3 "interface class" idiom — `with`/`extends` supplies real
// equality behavior, `implements` separately names a marker/contract
// interface purely for typing. The marker itself extends Equatable (so
// `_implementsValueEqualityType` correctly flags it as value-equality-based),
// but the concrete class's OWN extends/with clause already provides working
// equality, so the implements clause did not cause the footgun and must not
// fire.
// =============================================================================

// Contract-only marker: no fields, no equality declared directly here — it
// is never instantiated on its own, only used as an interface target.
abstract class ValueObject extends Equatable {}

// Equality comes from `with EquatableMixin`, not from `implements
// ValueObject` — the implements clause is purely a typing contract.
class Balance with EquatableMixin implements ValueObject {
  Balance(this.cents);
  final int cents;

  @override
  List<Object?> get props => <Object?>[cents];
}

// Equality comes from `extends Equatable`; `implements ValueObject` on top
// of that is a redundant-but-harmless marker, not the source of equality.
class Credit extends Equatable implements ValueObject {
  Credit(this.cents);
  final int cents;

  @override
  List<Object?> get props => <Object?>[cents];
}

// =============================================================================
// GOOD: equality is INHERITED from an ordinary (non-Equatable) base class.
// `extends` inherits implementation, so the pair below is live on every
// subclass — the `implements Equatable` clause never broke anything here.
// =============================================================================

// Hand-rolled value-equality contract on a plain base class.
class BaseValue {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

// Direct parent declares the pair.
class TenantId extends BaseValue implements Equatable {
  TenantId(this.value);
  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

// Intermediate link declaring nothing — the pair is two levels up, so the
// rule must walk the whole extends chain, not just the direct superclass.
class MidValue extends BaseValue {}

class RegionId extends MidValue implements Equatable {
  RegionId(this.value);
  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

// =============================================================================
// GOOD: equality inherited from a mixin that hand-rolls the pair. Mixins
// copy implementation in, exactly like `extends`.
// =============================================================================

mixin IdentityEquality {
  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class ShardId with IdentityEquality implements Equatable {
  ShardId(this.value);
  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

// =============================================================================
// GOOD near-miss: a PROJECT-LOCAL interface that merely reuses the name
// `Equatable` but is not a value type at all (no `props` member). Matching
// on the bare name would misdiagnose this class; the rule requires either
// a `package:equatable` origin or the structural `props` marker.
// =============================================================================

// NOTE: this file already declares one `Equatable` stand-in (the value-type
// one), and Dart forbids a second same-named declaration in the same
// library — so the exact `abstract class Equatable { bool matches(...); }`
// false positive is exercised in the unit test, which gets its own isolated
// library. What is pinned here is the shape: a same-flavored marker
// interface whose members have nothing to do with value equality.
abstract class MatchableEquatable {
  bool matches(Object other);
}

class ConfigKey implements MatchableEquatable {
  ConfigKey(this.name);
  final String name;

  @override
  bool matches(Object other) => other is ConfigKey && other.name == name;
}

// =============================================================================
// GOOD near-miss: `implements` an interface that declares `==`/`hashCode`
// signatures only. `implements` inherits NO implementation, so this class
// really is broken-by-identity — but it also does not implement a value
// type, so the rule stays silent rather than reporting the wrong reason.
// =============================================================================

abstract class EqualityContract {
  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

class BuildTag implements EqualityContract {
  BuildTag(this.value);
  final String value;
}

// ignore_for_file: unused_element

/// Fixtures for avoid_implementing_value_types.
library;

// Deliberately not importing package:equatable here (fixtures avoid adding
// external dependencies). The rule's fast path matches the `implements`
// clause name lexeme ('Equatable'/'EquatableMixin') directly, so a
// locally-declared stand-in class named `Equatable` still exercises the
// detection without a real dependency (see the rule test's harness comment
// for the same rationale).
abstract class Equatable {
  List<Object?> get props;
}

mixin EquatableMixin {
  List<Object?> get props;
}

// =============================================================================
// BAD: implements a value-equality type without redeclaring == / hashCode
// =============================================================================

// expect_lint: avoid_implementing_value_types
class UserId implements Equatable {
  UserId(this.value);
  final String value;

  @override
  List<Object?> get props => <Object?>[value];
  // == and hashCode are NOT inherited via `implements` — reference equality
  // silently applies, so this class breaks Set/Map-key/dedup semantics.
}

// expect_lint: avoid_implementing_value_types
class Money implements EquatableMixin {
  Money(this.cents);
  final int cents;

  @override
  List<Object?> get props => <Object?>[cents];
}

// Indirect case: OrderId doesn't name Equatable directly, but its supertype
// (extends Equatable) does — the rule walks resolved supertypes to catch
// this. Requires a resolved analysis context to fire (see scan --resolve).
// expect_lint: avoid_implementing_value_types
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

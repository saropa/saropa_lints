// ignore_for_file: unused_element, unused_field
// ignore_for_file: override_on_non_overriding_member, annotate_overrides

/// Fixture for `prefer_sorted_equatable_props` lint rule.

// Mock Equatable for testing (since we may not have equatable package).
abstract class Equatable {
  const Equatable();
  List<Object?> get props;
}

// BAD: props order (age, name, email) differs from declaration order
// (name, age, email).
class _BadPerson extends Equatable {
  final String name;
  final int age;
  final String email;

  const _BadPerson(this.name, this.age, this.email);

  @override
  // expect_lint: prefer_sorted_equatable_props
  List<Object?> get props => [age, name, email];
}

// GOOD: props order matches field declaration order.
class _GoodPerson extends Equatable {
  final String name;
  final int age;
  final String email;

  const _GoodPerson(this.name, this.age, this.email);

  @override
  List<Object?> get props => [name, age, email];
}

// GOOD: single field — no ordering to violate.
class _GoodSingleField extends Equatable {
  final String name;

  const _GoodSingleField(this.name);

  @override
  List<Object?> get props => [name];
}

// GOOD: props includes a computed expression (not a plain identifier) —
// rule skips non-field entries and only compares shared field identifiers.
class _GoodWithComputed extends Equatable {
  final String name;
  final int age;

  const _GoodWithComputed(this.name, this.age);

  @override
  List<Object?> get props => [name, name.toLowerCase(), age];
}

// GOOD: static fields are excluded from the declaration-order list,
// so only instance fields participate in the comparison.
class _GoodWithStatic extends Equatable {
  static const String category = 'people';
  final String name;
  final int age;

  const _GoodWithStatic(this.name, this.age);

  @override
  List<Object?> get props => [name, age];
}

// BAD: multiple variables in one FieldDeclaration — `a, b` declared
// together, then `c` separately. Props list has them out of order.
class _BadCombinedDeclaration extends Equatable {
  final String a, b;
  final String c;

  const _BadCombinedDeclaration(this.a, this.b, this.c);

  @override
  // expect_lint: prefer_sorted_equatable_props
  List<Object?> get props => [c, a, b];
}

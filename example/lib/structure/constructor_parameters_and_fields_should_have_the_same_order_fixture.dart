// ignore_for_file: unused_element, unused_field

/// Fixture for `constructor_parameters_and_fields_should_have_the_same_order`.
///
/// BAD cases: constructor `this.field` parameter order does not match the
/// order the same fields are declared in the class body.
/// GOOD cases: parameter order matches field order, or the mismatch does not
/// apply (too few fields, non-forwarding params, multiple constructors where
/// only one drifted).
library;

/// BAD — fields declared name, age, email but the constructor forwards
/// them in a completely different order (email, age, name).
class BadUserProfile {
  final String name;
  final int age;
  final String email;

  // expect_lint: constructor_parameters_and_fields_should_have_the_same_order
  BadUserProfile({
    required this.email,
    required this.age,
    required this.name,
  });
}

/// GOOD — constructor parameters match field declaration order exactly.
class GoodUserProfile {
  final String name;
  final int age;
  final String email;

  GoodUserProfile({
    required this.name,
    required this.age,
    required this.email,
  });
}

/// BAD — positional constructor whose forwarding order is reversed relative
/// to the field declarations.
class BadPoint3D {
  final double x;
  final double y;
  final double z;

  // expect_lint: constructor_parameters_and_fields_should_have_the_same_order
  BadPoint3D(this.z, this.y, this.x);
}

/// GOOD — only two of three fields are forwarded, and their relative order
/// (name, then email) still matches field declaration order; the omitted
/// `age` field (e.g. computed/late) is simply skipped from comparison.
class GoodPartialForwarding {
  final String name;
  final int age;
  final String email;

  GoodPartialForwarding({required this.name, required this.email})
    : age = 0;
}

/// BAD — one of two constructors on the same class has drifted order; each
/// constructor is checked independently against the same field order.
class MixedConstructors {
  final String first;
  final String second;

  // Default constructor: correctly ordered — no lint.
  MixedConstructors({required this.first, required this.second});

  // Named constructor: drifted order — flagged independently.
  // expect_lint: constructor_parameters_and_fields_should_have_the_same_order
  MixedConstructors.reversed({required this.second, required this.first});
}

/// GOOD — a parameter that isn't `this.field` shorthand (used only to
/// compute a derived value in the initializer list) has no field position
/// to compare against and is skipped entirely.
class GoodDerivedField {
  final String name;
  final int nameLength;

  GoodDerivedField({required this.name, required int rawLength})
    : nameLength = rawLength;
}

/// GOOD — fewer than two fields means there is no possible ordering to
/// violate.
class GoodSingleField {
  final String onlyField;

  GoodSingleField({required this.onlyField});
}

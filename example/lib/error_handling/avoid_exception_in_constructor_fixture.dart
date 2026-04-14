// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_exception_in_constructor` lint rule.

// BAD: Should trigger avoid_exception_in_constructor
class _BadUser {
  _BadUser(String email) {
    // expect_lint: avoid_exception_in_constructor
    throw ArgumentError('Invalid email'); // throw in constructor
  }
}

// GOOD: Should NOT trigger avoid_exception_in_constructor
class _GoodUser {
  _GoodUser._(this.email);
  final String email;
  factory _GoodUser(String email) {
    return _GoodUser._(email); // factory constructor — OK
  }
}

void main() {}

// ignore_for_file: unused_element

/// Fixture for `prefer_constructor_body_assignment` (opinionated opposite of this.field).

class User {
  final String name;

  // LINT: field formal blocks adding validation in the body
  User(this.name);
}

class UserExplicit {
  final String name;

  UserExplicit(String name) : this.name = name;
}

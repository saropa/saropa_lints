// Test fixture for: illegal_enum_values
// BAD: enum with instance member named "values" triggers the lint.
// GOOD: enum without instance "values" does not.

enum BadEnum {
  a,
  b;
  // LINT: illegal_enum_values — shadows static values getter
  int get values => 0;
}

enum GoodEnum {
  a,
  b;
  int get count => 0;
}

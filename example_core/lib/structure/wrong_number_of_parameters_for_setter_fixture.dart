// Test fixture for: wrong_number_of_parameters_for_setter
// BAD: setter with 0, 2+, optional, or named params triggers the lint.
// GOOD: setter with exactly one required positional does not.

class Bad {
  // LINT: wrong_number_of_parameters_for_setter
  set noParam() {}

  // LINT: wrong_number_of_parameters_for_setter
  set optional([int x]) {}
}

class Good {
  set value(int x) {}
}

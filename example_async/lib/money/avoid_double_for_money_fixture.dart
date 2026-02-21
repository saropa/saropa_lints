// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_double_for_money` lint rule.

// NOTE: avoid_double_for_money fires on double type used with
// money-related variable names (price, amount, total, etc.).
//
// BAD:
// double price = 19.99; // floating point rounding errors
//
// GOOD:
// int priceInCents = 1999; // integer cents — no rounding

void main() {}

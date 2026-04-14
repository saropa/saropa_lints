// ignore_for_file: unused_element
// Fixture for prefer_optional_positional_params: prefer optional positional for bool.

// LINT: optional named bool
void f({bool verbose = false}) {}

// OK: optional positional bool
void g([bool verbose = false]) {}

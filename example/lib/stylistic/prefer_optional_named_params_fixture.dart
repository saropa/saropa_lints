// ignore_for_file: unused_element
// Fixture for prefer_optional_named_params: prefer optional named over optional positional.

// LINT: optional positional params
void f([int x = 0, int y = 1]) {}

// OK: optional named
void g({int x = 0, int y = 1}) {}

// ignore_for_file: unused_element
// Fixture for avoid_explicit_type_declaration: prefer type inference when variable has initializer.

void f() {
  // LINT: explicit type with initializer
  int x = 1;

  // OK: inferred type
  final y = 1;
}

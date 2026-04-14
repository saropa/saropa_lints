// ignore_for_file: unused_element
// Fixture for prefer_inline_function_types: prefer inline over typedef.

// LINT: typedef for function type
typedef Predicate = bool Function(int);

void f(Predicate p) {}

// OK: inline type at use site (or typedef for non-function)
bool Function(int) g() => (x) => x > 0;

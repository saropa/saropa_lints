// ignore_for_file: unused_element
// Fixture for prefer_static_method_over_function: top-level with class-typed first param.

// LINT: could be extension or static method
String formatDate(DateTime dt) => dt.year.toString();

// OK: primitive first param
int add(int a, int b) => a + b;

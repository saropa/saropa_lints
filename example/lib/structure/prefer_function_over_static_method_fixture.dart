// ignore_for_file: unused_element
// Fixture for prefer_function_over_static_method: static method with no this.

class C {
  // LINT: static method could be top-level
  static int add(int a, int b) => a + b;
}

// OK: top-level
int add(int a, int b) => a + b;

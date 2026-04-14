// ignore_for_file: unused_element
// Fixture for prefer_non_const_constructors: prefer omitting const on constructors.

class C {
  // LINT: const constructor
  const C();
}

// OK: non-const constructor
class D {
  D();
}

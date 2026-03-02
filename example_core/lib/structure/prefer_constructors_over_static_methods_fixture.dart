// ignore_for_file: unused_element
// Fixture for prefer_constructors_over_static_methods: prefer factory over static method returning new SameClass.

class C {
  // LINT: static method that only returns new C()
  static C create() => C();

  // OK: factory constructor
  factory C.fromInt(int x) => C();
}

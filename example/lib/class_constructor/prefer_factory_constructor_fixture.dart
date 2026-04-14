// ignore_for_file: unused_element
// Fixture for prefer_factory_constructor: static method returning same class.

class C {
  // LINT: static method that could be factory
  static C create() => C();

  // OK: factory constructor
  factory C.fromInt(int x) => C();
}

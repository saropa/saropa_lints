// ignore_for_file: unused_element
// Fixture for prefer_factory_before_named.
// Rule: factory constructors should appear before named constructors.

// LINT: named constructor before factory
class BadOrder {
  BadOrder.named();
  factory BadOrder.foo() => BadOrder.named();
}

// OK: factory before named
class GoodOrder {
  factory GoodOrder.foo() => GoodOrder.named();
  GoodOrder.named();
}

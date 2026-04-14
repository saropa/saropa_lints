// ignore_for_file: unused_element
// Test fixture for: avoid_referencing_subclasses
// BAD: Base references Sub in return type
// expect_lint: avoid_referencing_subclasses
class Base {
  Sub create() => Sub();
}

class Sub extends Base {}

// GOOD: Base uses own type
class Base2 {
  Base2 create() => Sub2();
}

class Sub2 extends Base2 {}

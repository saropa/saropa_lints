// ignore_for_file: unused_element
// Fixture for prefer_overrides_last: override methods after non-override.

class Base {
  void bar() {}
}

// LINT: override before non-override
class Bad extends Base {
  @override
  void foo() {}
  void bar() {}
}

// OK: override last
class Good extends Base {
  void bar() {}
  @override
  void foo() {}
}

// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_constructor_injection` lint rule.

class MyService {}

// BAD: Should trigger prefer_constructor_injection
class _BadDI3 {
  // expect_lint: prefer_constructor_injection
  late MyService _service; // late field — use constructor injection
}

// GOOD: Should NOT trigger prefer_constructor_injection
class _GoodDI3 {
  final MyService _service;
  _GoodDI3(this._service); // injected via constructor
}

void main() {}

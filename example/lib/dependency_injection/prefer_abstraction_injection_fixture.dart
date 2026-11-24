// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_abstraction_injection` lint rule.

class _HttpClientImpl {} // concrete type

abstract class ApiClient {} // abstract interface

// BAD: Should trigger prefer_abstraction_injection
class _BadDI {
  // expect_lint: prefer_abstraction_injection
  _BadDI(_HttpClientImpl client); // Impl suffix — concrete type injected
}

// GOOD: Should NOT trigger prefer_abstraction_injection
class _GoodDI {
  _GoodDI(ApiClient client); // Abstract interface — testable
}

class _Dio {}

// GOOD: a factory closure returning a concrete-named type is the injection
// seam itself (tests pass a fake factory) - must NOT trigger.
class _GoodFactoryDI {
  _GoodFactoryDI({_Dio Function()? dioFactory});
}

void main() {}

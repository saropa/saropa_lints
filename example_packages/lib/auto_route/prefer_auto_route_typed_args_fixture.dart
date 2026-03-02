// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_auto_route_typed_args` lint rule.

// BAD: Untyped route args
// expect_lint: prefer_auto_route_typed_args
void bad(Object args) {}

// GOOD: Typed route args
void good({required String id, int? tab}) {}

void main() {}

// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_void_async` lint rule.

// BAD: async function returning void
// expect_lint: avoid_void_async
void bad() async {}

// GOOD: Future<void>
Future<void> good() async {}

void main() {}

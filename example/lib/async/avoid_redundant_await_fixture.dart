// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_redundant_await` lint rule.

// BAD: Await on non-Future
// expect_lint: avoid_redundant_await
Future<void> bad() async {
  await 1;
}

// GOOD: Await only on Future
Future<void> good() async {
  await Future.value(1);
}

void main() {}

// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_future_then_in_async` lint rule.

Future<String> _fetch() async => 'data';

// BAD: Should trigger avoid_future_then_in_async
Future<void> _bad() async {
  // expect_lint: avoid_future_then_in_async
  _fetch().then((data) => print(data)); // .then() inside async function
}

// GOOD: Should NOT trigger avoid_future_then_in_async
Future<void> _good() async {
  final data = await _fetch(); // use await instead of .then()
  print(data);
}

void main() {}

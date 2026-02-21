// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_future_wait` lint rule.

Future<String> _fetchA() async => 'a';
Future<String> _fetchB() async => 'b';

// BAD: Should trigger prefer_future_wait
Future<void> _bad() async {
  final a = await _fetchA(); // first sequential await
  // expect_lint: prefer_future_wait
  final b = await _fetchB(); // second — could parallelize
}

// GOOD: Should NOT trigger prefer_future_wait
Future<void> _good() async {
  final results = await Future.wait([_fetchA(), _fetchB()]);
}

void main() {}

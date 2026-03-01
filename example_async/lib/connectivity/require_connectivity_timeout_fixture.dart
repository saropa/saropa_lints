// ignore_for_file: unused_local_variable, unused_element
// Fixture for require_connectivity_timeout.

dynamic http;
final url = 'https://example.com';

// BAD: HTTP request without timeout — should trigger require_connectivity_timeout
// LINT
Future<void> badNoTimeout() async {
  final response = await http.get(Uri.parse(url));
}

// GOOD: Request with timeout — should NOT trigger
Future<void> goodWithTimeout() async {
  final response = await http
      .get(Uri.parse(url))
      .timeout(const Duration(seconds: 30));
}

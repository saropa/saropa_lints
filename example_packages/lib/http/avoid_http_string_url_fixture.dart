// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_http_string_url` (ERROR + quick fix).
library;

import 'package:http/http.dart' as http;

Future<void> bad() async {
  // expect_lint: avoid_http_string_url
  await http.get('https://example.com');
}

Future<void> good() async {
  // Uri.parse(...) is the http 1.x form — a different AST shape, never flagged.
  await http.get(Uri.parse('https://example.com'));
}

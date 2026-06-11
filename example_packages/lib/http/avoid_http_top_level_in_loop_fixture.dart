// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_http_top_level_in_loop` (WARNING).
library;

import 'package:http/http.dart' as http;

Future<void> bad(List<String> ids) async {
  for (final id in ids) {
    // expect_lint: avoid_http_top_level_in_loop
    await http.get(Uri.parse('https://api/$id'));
  }
}

Future<void> good(List<String> ids) async {
  final client = http.Client();
  try {
    for (final id in ids) {
      await client.get(Uri.parse('https://api/$id'));
    }
  } finally {
    client.close();
  }
}

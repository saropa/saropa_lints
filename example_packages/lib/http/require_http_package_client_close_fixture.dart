// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_http_package_client_close` (WARNING).
library;

import 'package:http/http.dart' as http;

Future<void> bad(Uri uri) async {
  // expect_lint: require_http_package_client_close
  final client = http.Client();
  await client.get(uri);
}

Future<void> good(Uri uri) async {
  final client = http.Client();
  try {
    await client.get(uri);
  } finally {
    client.close();
  }
}

/// Ownership transfers out — caller closes, so no report.
http.Client goodReturned() {
  final client = http.Client();
  return client;
}

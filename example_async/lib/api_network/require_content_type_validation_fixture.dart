// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: require_content_type_validation
// Source: lib/src/rules/network/api_network_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic body;
dynamic data;
dynamic request;

// BAD: jsonDecode without Content-Type check — should trigger
// expect_lint: require_content_type_validation
void badNoContentTypeCheck() {
  final data = jsonDecode(body);
  return;
}

// GOOD: Content-Type guard before decode — should NOT trigger
void goodWithContentTypeGuard() {
  if (request.headers.contentType?.mimeType != 'application/json') {
    return;
  }
  final data = jsonDecode(body);
  return;
}

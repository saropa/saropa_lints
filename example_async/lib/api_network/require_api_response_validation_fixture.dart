// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: require_api_response_validation
// Source: lib/src/rules/network/api_network_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic body;
dynamic data;

// BAD: decoded value used without validation — should trigger
// expect_lint: require_api_response_validation
void badUnvalidatedUse() {
  final data = jsonDecode(body);
  final x = data['key'];
  return;
}

// GOOD: inline fromJson — should NOT trigger
void goodInlineFromJson() {
  final data = _Model.fromJson(jsonDecode(body));
  return;
}

// GOOD: variable only passed to fromJson — should NOT trigger
void goodVariableOnlyToFromJson() {
  final decoded = jsonDecode(body);
  final data = _Model.fromJson(decoded);
  return;
}

class _Model {
  _Model(this.x);
  final String x;
  static _Model fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw StateError('expected map');
    return _Model(json['x'] as String);
  }
}

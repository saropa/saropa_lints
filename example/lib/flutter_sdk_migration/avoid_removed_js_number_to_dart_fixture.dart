// ignore_for_file: unused_element, undefined_getter
// Test fixture for: avoid_removed_js_number_to_dart
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart

class JSNumber {}

extension on JSNumber {
  double get toDartDouble => 0.0;
  int get toDartInt => 0;
}

double jsNumberToDartBad(JSNumber n) {
  // expect_lint: avoid_removed_js_number_to_dart
  return n.toDart;
}

double jsNumberToDartGoodDouble(JSNumber n) {
  return n.toDartDouble;
}

int jsNumberToDartGoodInt(JSNumber n) {
  return n.toDartInt;
}

int jsNumberToDartFalsePositive(_NotJsNumber n) {
  return n.toDart;
}

class _NotJsNumber {
  int get toDart => 0;
}

// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: no_runtimeType_toString
// Source: lib/src/rules/stylistic/stylistic_rules.dart

// BAD: Should trigger no_runtimeType_toString
void _badNoRuntimeTypeToString(Object value) {
  // expect_lint: no_runtimeType_toString
  final typeName = value.runtimeType.toString();
  print(typeName);
}

// GOOD: Should NOT trigger no_runtimeType_toString
void _goodNoRuntimeTypeToString(Object value) {
  final sameType = value.runtimeType == String;
  print(sameType);
}

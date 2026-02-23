// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_dropdown_initial_value
// Test fixture for: prefer_dropdown_initial_value
// Source: lib\src\rules\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'value' parameter
// expect_lint: prefer_dropdown_initial_value
Widget _badValue() {
  return DropdownButtonFormField<String>(
    value: 'hello',
    onChanged: (v) {},
    items: [],
  );
}

// GOOD: Using the new 'initialValue' parameter
Widget _goodInitialValue() {
  return DropdownButtonFormField<String>(
    initialValue: 'hello',
    onChanged: (v) {},
    items: [],
  );
}

// FALSE POSITIVE: DropdownButton (not FormField variant) has 'value' legitimately
Widget _fpDropdownButton() {
  return DropdownButton<String>(
    value: 'hello',
    onChanged: (v) {},
    items: [],
  );
}

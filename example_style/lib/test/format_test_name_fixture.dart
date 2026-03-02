// ignore_for_file: unused_element
// Fixture for format_test_name: test names must be snake_case.

import 'package:flutter_test/flutter_test.dart';

void main() {
  // LINT: not snake_case
  test('my Test Name', () {});

  // LINT: CamelCase
  testWidgets('MyWidgetTest', (t) {});

  // OK
  test('my_test_name', () {});
  testWidgets('my_widget_test', (t) {});
}

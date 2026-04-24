// ignore_for_file: unused_element
// Test fixture for: prefer_keyboard_listener_over_raw
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart
//
// Real BAD sites use package:flutter's RawKeyboardListener (see rule
// DartDoc). This package's mocks resolve to a non-flutter library URI, so
// expect_lint is not asserted here; the file exists for fixture coverage.

import '../flutter_mocks.dart';

Widget goodKeyboardListener() {
  return KeyboardListener(
    focusNode: FocusNode(),
    onKeyEvent: (_) {},
    child: const Text('x'),
  );
}

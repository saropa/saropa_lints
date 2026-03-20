// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_context_menu_builder
// Test fixture for: prefer_context_menu_builder
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'previewBuilder' parameter
// expect_lint: prefer_context_menu_builder
Widget _badPreviewBuilder() {
  return CupertinoContextMenu(
    previewBuilder: (context, animation, child) => child,
    child: const Text('long press me'),
  );
}

// GOOD: Using the new 'builder' parameter
Widget _goodBuilder() {
  return CupertinoContextMenu(
    builder: (context, animation) => const Text('preview'),
    child: const Text('long press me'),
  );
}

// GOOD: No builder parameter at all
Widget _goodNoBuilder() {
  return CupertinoContextMenu(
    child: const Text('long press me'),
  );
}

// FALSE POSITIVE: 'previewBuilder' on a different widget type
void _fpOtherWidget() {
  final map = {'previewBuilder': () {}};
}

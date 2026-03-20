// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_platform_menu_bar_child
// Test fixture for: prefer_platform_menu_bar_child
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'body' parameter
// expect_lint: prefer_platform_menu_bar_child
Widget _badBody() {
  return PlatformMenuBar(
    menus: [],
    body: const Text('app'),
  );
}

// GOOD: Using the new 'child' parameter
Widget _goodChild() {
  return PlatformMenuBar(
    menus: [],
    child: const Text('app'),
  );
}

// GOOD: No body or child parameter
Widget _goodNoBody() {
  return PlatformMenuBar(
    menus: [],
  );
}

// FALSE POSITIVE: 'body' named argument on a different widget type
void _fpOtherWidget() {
  final map = {'body': 'text'};
}

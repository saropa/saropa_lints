// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_button_style_icon_alignment
// Test fixture for: prefer_button_style_icon_alignment
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'iconAlignment' on ElevatedButton
// expect_lint: prefer_button_style_icon_alignment
Widget _badElevatedButton() {
  return ElevatedButton(
    onPressed: () {},
    iconAlignment: IconAlignment.end,
    child: const Text('Button'),
  );
}

// BAD: Using deprecated 'iconAlignment' on ElevatedButton.icon
// expect_lint: prefer_button_style_icon_alignment
Widget _badElevatedButtonIcon() {
  return ElevatedButton.icon(
    onPressed: () {},
    icon: const Icon(null),
    label: const Text('Button'),
    iconAlignment: IconAlignment.end,
  );
}

// BAD: Using deprecated 'iconAlignment' on TextButton
// expect_lint: prefer_button_style_icon_alignment
Widget _badTextButton() {
  return TextButton(
    onPressed: () {},
    iconAlignment: IconAlignment.end,
    child: const Text('Button'),
  );
}

// BAD: Using deprecated 'iconAlignment' on FilledButton
// expect_lint: prefer_button_style_icon_alignment
Widget _badFilledButton() {
  return FilledButton(
    onPressed: () {},
    iconAlignment: IconAlignment.end,
    child: const Text('Button'),
  );
}

// BAD: Using deprecated 'iconAlignment' on OutlinedButton
// expect_lint: prefer_button_style_icon_alignment
Widget _badOutlinedButton() {
  return OutlinedButton(
    onPressed: () {},
    iconAlignment: IconAlignment.end,
    child: const Text('Button'),
  );
}

// GOOD: Using ButtonStyle.iconAlignment via style parameter
Widget _goodStyleFrom() {
  return ElevatedButton.icon(
    onPressed: () {},
    icon: const Icon(null),
    label: const Text('Button'),
    style: ElevatedButton.styleFrom(iconAlignment: IconAlignment.end),
  );
}

// GOOD: No iconAlignment parameter at all
Widget _goodNoIconAlignment() {
  return ElevatedButton(
    onPressed: () {},
    child: const Text('Button'),
  );
}

// FALSE POSITIVE: iconAlignment in a map literal
void _fpMapLiteral() {
  final map = {'iconAlignment': 'end'};
}

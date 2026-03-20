// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_key_event
// Test fixture for: prefer_key_event
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated RawKeyboardListener type
// expect_lint: prefer_key_event
Widget _badRawKeyboardListener() {
  return RawKeyboardListener(
    focusNode: FocusNode(),
    onKey: (event) {},
    child: const Text('listener'),
  );
}

// BAD: Using deprecated RawKeyEvent type annotation
// expect_lint: prefer_key_event
void _badRawKeyEventType(RawKeyEvent event) {}

// BAD: Using deprecated RawKeyDownEvent in is-check
void _badRawKeyDownCheck(dynamic event) {
  // expect_lint: prefer_key_event
  if (event is RawKeyDownEvent) {}
}

// BAD: Using deprecated RawKeyUpEvent in is-check
void _badRawKeyUpCheck(dynamic event) {
  // expect_lint: prefer_key_event
  if (event is RawKeyUpEvent) {}
}

// BAD: Using deprecated RawKeyboard type
// expect_lint: prefer_key_event
void _badRawKeyboard(RawKeyboard keyboard) {}

// BAD: Using deprecated 'onKey:' on Focus
// expect_lint: prefer_key_event
Widget _badFocusOnKey() {
  return Focus(
    onKey: (node, event) {},
    child: const Text('focus'),
  );
}

// BAD: Using deprecated 'onKey:' on FocusNode
void _badFocusNodeOnKey() {
  // expect_lint: prefer_key_event
  FocusNode(onKey: (node, event) {});
}

// GOOD: Using KeyboardListener (replacement for RawKeyboardListener)
Widget _goodKeyboardListener() {
  return KeyboardListener(
    focusNode: FocusNode(),
    onKeyEvent: (event) {},
    child: const Text('listener'),
  );
}

// GOOD: Using KeyEvent type (replacement for RawKeyEvent)
void _goodKeyEventType(KeyEvent event) {}

// GOOD: Using KeyDownEvent (replacement for RawKeyDownEvent)
void _goodKeyDownCheck(dynamic event) {
  if (event is KeyDownEvent) {}
}

// GOOD: Using onKeyEvent instead of onKey on Focus
Widget _goodFocusOnKeyEvent() {
  return Focus(
    onKeyEvent: (node, event) {},
    child: const Text('focus'),
  );
}

// FALSE POSITIVE: 'RawKey' string in a comment or variable name
void _fpRawKeyString() {
  final rawKeyName = 'some raw key value';
}

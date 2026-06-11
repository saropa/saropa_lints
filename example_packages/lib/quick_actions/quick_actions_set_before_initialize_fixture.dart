// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `quick_actions_set_before_initialize`.
///
/// BAD: setShortcutItems runs before initialize on the same QuickActions
/// instance, so a cold-start tap is dropped. GOOD: initialize first (awaited
/// or via .then), then setShortcutItems.
library;

import 'package:quick_actions/quick_actions.dart';

Future<void> bad() async {
  final QuickActions qa = const QuickActions();
  // expect_lint: quick_actions_set_before_initialize
  await qa.setShortcutItems(<ShortcutItem>[]);
  await qa.initialize((String type) {});
}

Future<void> goodAwait() async {
  final QuickActions qa = const QuickActions();
  await qa.initialize((String type) {});
  await qa.setShortcutItems(<ShortcutItem>[]);
}

void goodThenChain() {
  final QuickActions qa = const QuickActions();
  qa
      .initialize((String type) {})
      .then((_) => qa.setShortcutItems(<ShortcutItem>[]));
}

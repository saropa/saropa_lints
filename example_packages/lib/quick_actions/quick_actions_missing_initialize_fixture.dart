// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `quick_actions_missing_initialize`.
///
/// BAD: a class registers shortcuts but never calls initialize, so cold-start
/// taps are dropped. GOOD: the class also calls initialize.
library;

import 'package:quick_actions/quick_actions.dart';

class BadShortcutSetup {
  final QuickActions qa = const QuickActions();

  void register() {
    // expect_lint: quick_actions_missing_initialize
    qa.setShortcutItems(<ShortcutItem>[]);
  }
}

class GoodShortcutSetup {
  final QuickActions qa = const QuickActions();

  void register() {
    qa.initialize((String type) {});
    qa.setShortcutItems(<ShortcutItem>[]);
  }
}

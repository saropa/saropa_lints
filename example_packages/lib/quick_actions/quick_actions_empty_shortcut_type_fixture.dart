// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `quick_actions_empty_shortcut_type`.
///
/// BAD: empty `type` string is never matched by a handler branch. GOOD: a
/// unique non-empty type. Quick fix replaces '' with 'action_placeholder'.
library;

import 'package:quick_actions/quick_actions.dart';

void bad() {
  // expect_lint: quick_actions_empty_shortcut_type
  const ShortcutItem(type: '', localizedTitle: 'Search');
}

void good() {
  const ShortcutItem(type: 'search', localizedTitle: 'Search');
}

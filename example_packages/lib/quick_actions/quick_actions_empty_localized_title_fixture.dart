// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `quick_actions_empty_localized_title`.
///
/// BAD: empty `localizedTitle` renders a blank/suppressed launcher entry.
/// GOOD: a readable, localized label.
library;

import 'package:quick_actions/quick_actions.dart';

void bad() {
  // expect_lint: quick_actions_empty_localized_title
  const ShortcutItem(type: 'search', localizedTitle: '');
}

void good() {
  const ShortcutItem(type: 'search', localizedTitle: 'Search');
}

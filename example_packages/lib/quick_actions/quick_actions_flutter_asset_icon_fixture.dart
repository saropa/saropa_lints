// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `quick_actions_flutter_asset_icon`.
///
/// BAD: a Flutter `assets/` path passed where a native resource name is
/// required produces a shortcut with no icon. GOOD: a native resource name.
library;

import 'package:quick_actions/quick_actions.dart';

void bad() {
  // expect_lint: quick_actions_flutter_asset_icon
  const ShortcutItem(
    type: 'search',
    localizedTitle: 'Search',
    icon: 'assets/icons/search.png',
  );
}

void good() {
  const ShortcutItem(
    type: 'search',
    localizedTitle: 'Search',
    icon: 'ic_search',
  );
}

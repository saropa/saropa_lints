// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `home_widget_callback_not_top_level`.
///
/// BAD: a closure passed as the callback. GOOD: a top-level function reference.
library;

import 'package:home_widget/home_widget.dart';

@pragma('vm:entry-point')
void onTap(Uri? uri) {}

Future<void> bad() async {
  // expect_lint: home_widget_callback_not_top_level
  await HomeWidget.registerInteractivityCallback((Uri? uri) {});
}

Future<void> good() async {
  await HomeWidget.registerInteractivityCallback(onTap);
}

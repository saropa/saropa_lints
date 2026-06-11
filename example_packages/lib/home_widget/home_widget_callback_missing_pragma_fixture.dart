// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `home_widget_callback_missing_pragma`.
///
/// BAD: top-level callback without @pragma('vm:entry-point'). GOOD: annotated.
library;

import 'package:home_widget/home_widget.dart';

void onWidgetTapBad(Uri? uri) {}

@pragma('vm:entry-point')
void onWidgetTapGood(Uri? uri) {}

Future<void> registerBad() async {
  // expect_lint: home_widget_callback_missing_pragma
  await HomeWidget.registerInteractivityCallback(onWidgetTapBad);
}

Future<void> registerGood() async {
  await HomeWidget.registerInteractivityCallback(onWidgetTapGood);
}

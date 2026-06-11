// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `home_widget_save_without_update`.
///
/// BAD: saveWidgetData with no updateWidget in the member. GOOD: paired.
library;

import 'package:home_widget/home_widget.dart';

Future<void> bad() async {
  // expect_lint: home_widget_save_without_update
  await HomeWidget.saveWidgetData('count', 1);
}

Future<void> good() async {
  await HomeWidget.saveWidgetData('count', 1);
  await HomeWidget.updateWidget(name: 'MyWidget');
}

// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `home_widget_update_no_name`.
///
/// BAD: updateWidget() with no name argument. GOOD: a widget name provided.
library;

import 'package:home_widget/home_widget.dart';

Future<void> bad() async {
  // expect_lint: home_widget_update_no_name
  await HomeWidget.updateWidget();
}

Future<void> good() async {
  await HomeWidget.updateWidget(name: 'MyWidgetProvider');
}

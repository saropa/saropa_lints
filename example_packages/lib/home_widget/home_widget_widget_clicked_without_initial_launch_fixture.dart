// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `home_widget_widget_clicked_without_initial_launch` (INFO).
///
/// BAD: class listens to widgetClicked with no initiallyLaunchedFromHomeWidget.
/// GOOD: both present.
library;

import 'package:home_widget/home_widget.dart';

class BadHandler {
  void start() {
    // expect_lint: home_widget_widget_clicked_without_initial_launch
    HomeWidget.widgetClicked.listen((_) {});
  }
}

class GoodHandler {
  Future<void> start() async {
    HomeWidget.widgetClicked.listen((_) {});
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  }
}

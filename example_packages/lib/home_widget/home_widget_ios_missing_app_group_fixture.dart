// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `home_widget_ios_missing_app_group`.
///
/// BAD: class saves widget data with no setAppGroupId. GOOD: setAppGroupId
/// present in the class.
library;

import 'package:home_widget/home_widget.dart';

class BadStore {
  Future<void> save() async {
    // expect_lint: home_widget_ios_missing_app_group
    await HomeWidget.saveWidgetData('count', 1);
  }
}

class GoodStore {
  Future<void> init() async {
    await HomeWidget.setAppGroupId('group.com.example.app');
  }

  Future<void> save() async {
    await HomeWidget.saveWidgetData('count', 1);
  }
}

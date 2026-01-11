// ignore_for_file: unused_local_variable, unused_element, unused_field
// Test fixture for lifecycle rules added in v2.3.10

import '../flutter_mocks.dart';

// =========================================================================
// require_did_update_widget_check
// =========================================================================
// Warns when didUpdateWidget doesn't compare oldWidget.

// BAD: didUpdateWidget without comparing oldWidget
class BadDidUpdateWidgetNoComparison extends StatefulWidget {
  const BadDidUpdateWidgetNoComparison({super.key, required this.value});
  final String value;

  @override
  State<BadDidUpdateWidgetNoComparison> createState() =>
      _BadDidUpdateWidgetNoComparisonState();
}

class _BadDidUpdateWidgetNoComparisonState
    extends State<BadDidUpdateWidgetNoComparison> {
  @override
  // expect_lint: require_did_update_widget_check
  void didUpdateWidget(BadDidUpdateWidgetNoComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateState(); // Always updates, even if nothing changed!
  }

  void _updateState() {}

  @override
  Widget build(BuildContext context) => Container();
}

// BAD: didUpdateWidget that only logs without comparison
class BadDidUpdateWidgetLogsOnly extends StatefulWidget {
  const BadDidUpdateWidgetLogsOnly({super.key, required this.value});
  final String value;

  @override
  State<BadDidUpdateWidgetLogsOnly> createState() =>
      _BadDidUpdateWidgetLogsOnlyState();
}

class _BadDidUpdateWidgetLogsOnlyState
    extends State<BadDidUpdateWidgetLogsOnly> {
  @override
  // expect_lint: require_did_update_widget_check
  void didUpdateWidget(BadDidUpdateWidgetLogsOnly oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('Widget updated'); // No comparison, just logging
    _doWork();
  }

  void _doWork() {}
  void print(String msg) {}

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: didUpdateWidget with proper comparison
class GoodDidUpdateWidgetWithComparison extends StatefulWidget {
  const GoodDidUpdateWidgetWithComparison({super.key, required this.value});
  final String value;

  @override
  State<GoodDidUpdateWidgetWithComparison> createState() =>
      _GoodDidUpdateWidgetWithComparisonState();
}

class _GoodDidUpdateWidgetWithComparisonState
    extends State<GoodDidUpdateWidgetWithComparison> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetWithComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _updateState(); // Only updates when value changed
    }
  }

  void _updateState() {}

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: didUpdateWidget that only calls super (nothing to compare)
class GoodDidUpdateWidgetSuperOnly extends StatefulWidget {
  const GoodDidUpdateWidgetSuperOnly({super.key});

  @override
  State<GoodDidUpdateWidgetSuperOnly> createState() =>
      _GoodDidUpdateWidgetSuperOnlyState();
}

class _GoodDidUpdateWidgetSuperOnlyState
    extends State<GoodDidUpdateWidgetSuperOnly> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetSuperOnly oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: didUpdateWidget with equality check
class GoodDidUpdateWidgetEquality extends StatefulWidget {
  const GoodDidUpdateWidgetEquality({super.key, required this.data});
  final List<String> data;

  @override
  State<GoodDidUpdateWidgetEquality> createState() =>
      _GoodDidUpdateWidgetEqualityState();
}

class _GoodDidUpdateWidgetEqualityState
    extends State<GoodDidUpdateWidgetEquality> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetEquality oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _refreshData();
    }
  }

  void _refreshData() {}

  @override
  Widget build(BuildContext context) => Container();
}

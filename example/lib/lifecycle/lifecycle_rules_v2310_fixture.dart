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

// GOOD: didUpdateWidget with listEquals
class GoodDidUpdateWidgetListEquals extends StatefulWidget {
  const GoodDidUpdateWidgetListEquals({
    super.key,
    required this.countries,
  });
  final List<String> countries;

  @override
  State<GoodDidUpdateWidgetListEquals> createState() =>
      _GoodDidUpdateWidgetListEqualsState();
}

class _GoodDidUpdateWidgetListEqualsState
    extends State<GoodDidUpdateWidgetListEquals> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetListEquals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countries, oldWidget.countries)) {
      _reload();
    }
  }

  void _reload() {}

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: didUpdateWidget with multiple listEquals checks
class GoodDidUpdateWidgetMultiListEquals extends StatefulWidget {
  const GoodDidUpdateWidgetMultiListEquals({
    super.key,
    required this.contacts,
    required this.activities,
  });
  final List<String> contacts;
  final List<String> activities;

  @override
  State<GoodDidUpdateWidgetMultiListEquals> createState() =>
      _GoodDidUpdateWidgetMultiListEqualsState();
}

class _GoodDidUpdateWidgetMultiListEqualsState
    extends State<GoodDidUpdateWidgetMultiListEquals> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetMultiListEquals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.contacts, oldWidget.contacts) ||
        !listEquals(widget.activities, oldWidget.activities)) {
      _refresh();
    }
  }

  void _refresh() {}

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: didUpdateWidget with setEquals
class GoodDidUpdateWidgetSetEquals extends StatefulWidget {
  const GoodDidUpdateWidgetSetEquals({super.key, required this.tags});
  final Set<String> tags;

  @override
  State<GoodDidUpdateWidgetSetEquals> createState() =>
      _GoodDidUpdateWidgetSetEqualsState();
}

class _GoodDidUpdateWidgetSetEqualsState
    extends State<GoodDidUpdateWidgetSetEquals> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetSetEquals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(widget.tags, oldWidget.tags)) {
      _refresh();
    }
  }

  void _refresh() {}

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: didUpdateWidget with mapEquals
class GoodDidUpdateWidgetMapEquals extends StatefulWidget {
  const GoodDidUpdateWidgetMapEquals({super.key, required this.config});
  final Map<String, String> config;

  @override
  State<GoodDidUpdateWidgetMapEquals> createState() =>
      _GoodDidUpdateWidgetMapEqualsState();
}

class _GoodDidUpdateWidgetMapEqualsState
    extends State<GoodDidUpdateWidgetMapEquals> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetMapEquals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(widget.config, oldWidget.config)) {
      _apply();
    }
  }

  void _apply() {}

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: didUpdateWidget with identical
class GoodDidUpdateWidgetIdentical extends StatefulWidget {
  const GoodDidUpdateWidgetIdentical({
    super.key,
    required this.callback,
  });
  final VoidCallback callback;

  @override
  State<GoodDidUpdateWidgetIdentical> createState() =>
      _GoodDidUpdateWidgetIdenticalState();
}

class _GoodDidUpdateWidgetIdenticalState
    extends State<GoodDidUpdateWidgetIdentical> {
  @override
  void didUpdateWidget(GoodDidUpdateWidgetIdentical oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.callback, oldWidget.callback)) {
      _rebind();
    }
  }

  void _rebind() {}

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// Widget Lifecycle Rules (from v4.1.4)
// =========================================================================

class BadDialogWidget extends StatefulWidget {
  const BadDialogWidget({super.key});

  @override
  State<BadDialogWidget> createState() => _BadDialogWidgetState();
}

class _BadDialogWidgetState extends State<BadDialogWidget> {
  @override
  void initState() {
    super.initState();
    // expect_lint: require_widgets_binding_callback
    showDialog(context: context, builder: (_) => Container());
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using addPostFrameCallback
class GoodDialogWidget extends StatefulWidget {
  const GoodDialogWidget({super.key});

  @override
  State<GoodDialogWidget> createState() => _GoodDialogWidgetState();
}

class _GoodDialogWidgetState extends State<GoodDialogWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(context: context, builder: (_) => Container());
    });
  }

  @override
  Widget build(BuildContext context) => Container();
}

Future<T?> showDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) async =>
    null;

class WidgetsBinding {
  static final WidgetsBinding instance = WidgetsBinding._();
  WidgetsBinding._();
  void addPostFrameCallback(void Function(Duration) callback) {}
}

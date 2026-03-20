// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_pan_axis
// Test fixture for: prefer_pan_axis
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'alignPanAxis' parameter
// expect_lint: prefer_pan_axis
Widget _badAlignPanAxis() {
  return InteractiveViewer(
    alignPanAxis: true,
    child: const Text('content'),
  );
}

// BAD: alignPanAxis set to false (also deprecated)
// expect_lint: prefer_pan_axis
Widget _badAlignPanAxisFalse() {
  return InteractiveViewer(
    alignPanAxis: false,
    child: const Text('content'),
  );
}

// GOOD: Using the new 'panAxis' enum parameter
Widget _goodPanAxis() {
  return InteractiveViewer(
    panAxis: PanAxis.aligned,
    child: const Text('content'),
  );
}

// GOOD: No pan axis parameter at all (default is PanAxis.free)
Widget _goodDefault() {
  return InteractiveViewer(
    child: const Text('content'),
  );
}

// FALSE POSITIVE: 'alignPanAxis' string in a map literal
void _fpMapLiteral() {
  final map = {'alignPanAxis': true};
}

// ignore_for_file: unused_local_variable

import '../flutter_mocks.dart';

/// Fixture for `prefer_ternary_over_collection_if` (opinionated opposite).

List<Widget> badExamples(bool show) {
  return [
    // LINT: collection-if → ternary-spread for this style rule
    if (show) const SizedBox(),
  ];
}

List<Widget> goodExamples(bool show) {
  return [
    ...(show ? [const SizedBox()] : []),
  ];
}

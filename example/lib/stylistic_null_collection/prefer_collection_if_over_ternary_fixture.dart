// ignore_for_file: unused_local_variable

import '../flutter_mocks.dart';

/// Fixture for `prefer_collection_if_over_ternary`.

List<Widget> badExamples(bool showExtra) {
  return [
    const SizedBox(),
    // LINT: ternary + empty list → use collection-if
    ...(showExtra ? [const SizedBox()] : []),
  ];
}

List<Widget> goodExamples(bool showExtra) {
  return [const SizedBox(), if (showExtra) const SizedBox()];
}

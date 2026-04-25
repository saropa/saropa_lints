// ignore_for_file: unused_element

import '../flutter_mocks.dart';

/// Fixture for `prefer_semantics_sort`.

Widget badSemantics() {
  // LINT: Semantics without sortKey in layouts that may need explicit order
  return const Semantics(label: 'region', child: SizedBox());
}

Widget goodSemantics() {
  return const Semantics(
    label: 'region',
    sortKey: OrdinalSortKey(1.0),
    child: SizedBox(),
  );
}

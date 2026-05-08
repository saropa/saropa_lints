// ignore_for_file: unused_local_variable, unused_element

import 'package:saropa_lints_example/flutter_mocks.dart';

/// Fixture for `avoid_redundant_semantics` lint rule.

Widget redundantSemanticsAroundImageBad() {
  // expect_lint: avoid_redundant_semantics
  return Semantics(
    label: 'Company logo',
    child: Image.network(
      'https://example.com/logo.png',
      semanticLabel: 'Company logo',
    ),
  );
}

Widget redundantSemanticsAroundImageGood() {
  return Image.network(
    'https://example.com/logo.png',
    semanticLabel: 'Company logo',
  );
}

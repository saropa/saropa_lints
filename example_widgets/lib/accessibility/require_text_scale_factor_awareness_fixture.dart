// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: require_text_scale_factor_awareness

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: fixed height with Text — expect_lint: require_text_scale_factor_awareness
Widget badFixedHeightText() {
  return Container(
    height: 48,
    child: const Text('Label'),
  );
}

// GOOD: no fixed height
Widget goodFlexibleText() {
  return Container(
    child: const Text('Label'),
  );
}

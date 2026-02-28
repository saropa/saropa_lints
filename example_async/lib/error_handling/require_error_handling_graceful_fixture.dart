// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: require_error_handling_graceful

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: raw exception in UI — expect_lint: require_error_handling_graceful
void badShowError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString())),
  );
}

// GOOD: friendly message
void goodShowError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Something went wrong. Please try again.')),
  );
}

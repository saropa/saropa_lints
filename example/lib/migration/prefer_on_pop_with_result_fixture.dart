// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_on_pop_with_result
// Test fixture for: prefer_on_pop_with_result
// Source: lib\src\rules\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'onPop' named argument
// expect_lint: prefer_on_pop_with_result
void _badOnPop() {
  MaterialPageRoute(
    builder: (context) => const Text('detail'),
    onPop: () {},
  );
}

// GOOD: Using the new 'onPopWithResult' parameter
void _goodOnPopWithResult() {
  MaterialPageRoute(
    builder: (context) => const Text('detail'),
    onPopWithResult: (result) {},
  );
}

// GOOD: No onPop parameter at all
void _goodNoOnPop() {
  MaterialPageRoute(
    builder: (context) => const Text('detail'),
  );
}

// FALSE POSITIVE: A map literal with 'onPop' key is not a named argument
void _fpMapLiteral() {
  final map = {'onPop': true};
}

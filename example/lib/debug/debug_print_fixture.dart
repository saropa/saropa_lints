// Fixture to test quick fixes for debug print rules.
//
// Quick fix available: "Comment out debugPrint statement"
// Quick fix available: "Comment out print statement"

// ignore_for_file: unused_local_variable

void debugPrintExample() {
  final value = 42;

  // expect_lint: avoid_debug_print
  debugPrint('Debug value: $value');

  // expect_lint: avoid_print_in_production
  print('Production print: $value');
}

void alreadyFixed() {
  final value = 42;

  // Commented out by quick fix - preserves developer intent
  // debugPrint('Debug value: $value');

  // Commented out by quick fix - preserves developer intent
  // print('Production print: $value');
}

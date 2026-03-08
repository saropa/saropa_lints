// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: prefer_sentence_case_comments
// Source: lib/src/rules/stylistic/stylistic_rules.dart

// ============================================================
// BAD: Should trigger prefer_sentence_case_comments (3+ words)
// ============================================================

// expect_lint: prefer_sentence_case_comments
// calculate the total price

// expect_lint: prefer_sentence_case_comments
// this is a helper function

// expect_lint: prefer_sentence_case_comments
// returns the user name from database

void _badExamples() {
  // expect_lint: prefer_sentence_case_comments
  // sets up the test environment properly
  final x = 1;
}

// ============================================================
// GOOD: Should NOT trigger prefer_sentence_case_comments
// ============================================================

// Capitalized prose comment (correct)
// Calculate the total price
// This is a helper function

// 1-2 word comments (skipped as annotations)
// magnifyingGlass
// gear
// not used
// see above

// Special markers
// TODO: fix this later
// FIXME: broken edge case
// NOTE: important detail

// camelCase/snake_case identifier references
// userId is the primary key for lookups
// user_name holds the display name string

// Commented-out code (keywords)
// return value;
// if (condition) { doStuff(); }

// Commented-out code (constructs)
// doSomething();
// _privateMethod

void _goodExamples() {
  // Capitalized 3-word comment
  final x = 1;

  // ok
  final y = 2;

  // magnifyingGlass
  final z = 3;
}

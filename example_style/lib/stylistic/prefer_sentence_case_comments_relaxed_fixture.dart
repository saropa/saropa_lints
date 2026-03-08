// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: prefer_sentence_case_comments_relaxed
// Source: lib/src/rules/stylistic/stylistic_rules.dart

// ============================================================
// BAD: Should trigger prefer_sentence_case_comments_relaxed (5+ words)
// ============================================================

// expect_lint: prefer_sentence_case_comments_relaxed
// calculate the total price including tax

// expect_lint: prefer_sentence_case_comments_relaxed
// this function sets up the test environment

void _badExamples() {
  // expect_lint: prefer_sentence_case_comments_relaxed
  // returns the primary user name from the database
  final x = 1;
}

// ============================================================
// GOOD: Should NOT trigger prefer_sentence_case_comments_relaxed
// ============================================================

// Capitalized long comment (correct)
// Calculate the total price including tax

// 1-4 word comments (skipped — within threshold)
// magnifyingGlass
// gear
// not used
// see above
// calculate the total
// this is fine

// Special markers
// TODO: fix this later
// FIXME: broken edge case
// NOTE: important detail

// camelCase/snake_case identifier references
// userId is the primary key for lookups
// user_name holds the display name string

void _goodExamples() {
  // Capitalized comment is fine
  final x = 1;

  // short note
  final y = 2;
}

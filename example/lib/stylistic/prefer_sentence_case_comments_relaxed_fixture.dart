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

// Multi-line continuation: second line is not a new sentence
// Health and generation before query check so probes /
// live-refresh work without DB.

// Multi-line continuation: three lines continuing a sentence
// VM-only implementation: this file is selected by conditional export when
// dart.library.io is available. The stub (drift_debug_server_stub.dart) is
// used on web.

// Continuation after colon (colon is not a sentence terminator)
// Things to consider:
// first check the input parameters carefully

// New sentence after period IS still checked (uppercase = OK)
// First sentence ends here.
// Second sentence starts with uppercase.

void _goodExamples() {
  // Capitalized comment is fine
  final x = 1;

  // short note
  final y = 2;
}

// ============================================================
// BAD: New sentence after period with lowercase start (5+ words)
// ============================================================

// First sentence ends here.
// expect_lint: prefer_sentence_case_comments_relaxed
// second sentence should be capitalized in this comment

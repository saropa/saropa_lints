// ignore_for_file: unused_local_variable, unused_element

/// Fixture file for prefer_no_commented_out_code rule.
/// This rule warns when commented-out code is detected.
/// Prose comments are NOT flagged - only code-like patterns.

// =============================================================================
// BAD: Commented-out code (should trigger lint)
// =============================================================================

void badExamples() {
  // expect_lint: prefer_no_commented_out_code
  // final oldValue = compute();

  // expect_lint: prefer_no_commented_out_code
  // return x;

  // expect_lint: prefer_no_commented_out_code
  // if (condition) {

  // expect_lint: prefer_no_commented_out_code
  // for (int i = 0; i < 10; i++) {

  // expect_lint: prefer_no_commented_out_code
  // while (running) {

  // expect_lint: prefer_no_commented_out_code
  // myList.add(item);

  // expect_lint: prefer_no_commented_out_code
  // doSomething();

  // expect_lint: prefer_no_commented_out_code
  // x = 5;

  // expect_lint: prefer_no_commented_out_code
  // foo.bar()

  // expect_lint: prefer_no_commented_out_code
  // @override

  // expect_lint: prefer_no_commented_out_code
  // import 'package:flutter/material.dart';

  // expect_lint: prefer_no_commented_out_code
  // class MyClass {

  // expect_lint: prefer_no_commented_out_code
  // }

  // expect_lint: prefer_no_commented_out_code
  // {

  // expect_lint: prefer_no_commented_out_code
  // (a, b) => a + b

  // expect_lint: prefer_no_commented_out_code
  // statement;

  // expect_lint: prefer_no_commented_out_code
  // int value = 0;

  // expect_lint: prefer_no_commented_out_code
  // String name = "test";

  // expect_lint: prefer_no_commented_out_code
  // List<int> items = [];

  // Literals in code context (should still trigger)
  // expect_lint: prefer_no_commented_out_code
  // null;

  // expect_lint: prefer_no_commented_out_code
  // true,

  // expect_lint: prefer_no_commented_out_code
  // return null;

  // expect_lint: prefer_no_commented_out_code
  // return false;
}

// =============================================================================
// GOOD: Prose comments (should NOT trigger lint)
// =============================================================================

void goodExamples() {
  // This is a regular prose comment
  // The user can click here to submit
  // Note that this feature is experimental
  // Always remember to validate input
  // Check if the value is null before proceeding
  // This method handles authentication
  // Returns true if successful, false otherwise

  // Prose with keywords (should NOT trigger - regression test for false positives)
  // null is before non-null, null is not before null
  // true means the operation succeeded
  // false indicates an error occurred
  // return when the condition is met
  // return to the previous state after completion
}

// =============================================================================
// GOOD: Special comment markers (automatically skipped)
// =============================================================================

void specialCommentsExamples() {
  // TODO: implement this feature
  // FIXME: handle edge case
  // NOTE: this is important
  // HACK: temporary workaround
  // XXX: needs review
  // BUG: known issue #123
  // OPTIMIZE: could be faster
  // WARNING: deprecated in v2.0
  // CHANGED: updated logic
  // REVIEW: check with team
  // DEPRECATED: use newMethod instead
  // IMPORTANT: must not change
  // MARK: - Section header
  // See: https://example.com/docs
  // ignore: unused_variable
  // ignore_for_file: avoid_print
  // cspell: disable-next-line
}

// =============================================================================
// GOOD: Doc comments (only single-line comments are checked)
// =============================================================================

/// final x = 5; - This is a doc comment, not checked
/// return value; - Doc comments have different conventions
void docCommentExample() {}

// =============================================================================
// EDGE CASES
// =============================================================================

void edgeCases() {
  // Empty comments are skipped
  //
  //

  // Numbers at start are not lowercase letters
  // 123 items in the list

  // Punctuation at start
  // - list item
  // * bullet point
}

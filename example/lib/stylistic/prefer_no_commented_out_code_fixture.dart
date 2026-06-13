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

  // Section headers with type names (should NOT trigger)
  // Iterable extensions
  // List extensions
  // Map extensions and utilities
  // String extensions and utilities

  // Inline prose containing keywords (should NOT trigger)
  // this is non-null, other is null
  // this is smaller
  // Map the list of enum values to a list of their names as strings
  // new set with the same elements as this iterable
  // Iterate over each row in the matrix
  // Sort the list of names in alphabetical order
  // Use expand() method to flatten the 2D list and create a

  // Prose with parenthetical ranges and English semicolons (should NOT trigger)
  // Stop button resets all controllers. Speed slider (0.25×–4×) is local to this tab;
  // Widget handles tap events (see docs); delegates to parent controller.
  // Default timeout is 30s (configurable via settings); zero disables it.
  // Parse results (JSON or XML) are cached; expired entries are evicted hourly.
  // The overlay (semi-transparent) covers the viewport; tapping dismisses it.

  // Single word ending a wrapped prose sentence with a period (should NOT
  // trigger - a trailing dot with nothing after it is sentence punctuation,
  // not member access)
  // result.
  // value.
  // done.

  // A wrapped prose block whose final physical line is one word + period
  // (should NOT trigger on the last line)
  // Dart ints are 64-bit, so the shift chain must reach 32: stopping at 16
  // leaves inputs above 2^32 with an unfilled high half and a wrong
  // result.

  // A contiguous prose block whose middle/last line references an API as
  // identifier.method (textually identical to member access, but the block is
  // prose - should NOT trigger on any line)
  // base64url omits padding, but base64Url.decode requires the length to be a
  // multiple of four - restore the stripped padding before decoding so that
  // base64Url.decode reject an otherwise-valid token.

  // A wrapped prose sentence whose middle line cites a function call with
  // arguments mid-sentence (should NOT trigger - the middle line is a lowercase
  // continuation fragment with function words, not a statement)
  // Clamp to 20: toStringAsFixed throws above 20 digits. Without
  // this, formatNumberLocale(x, decimalPlaces: 25) crashed (formatDouble in
  // double_extensions already clamps the same way).

  // A wrapped prose line ending with an unbalanced parenthetical that names a
  // call (should NOT trigger - mid-sentence prose, open paren left dangling)
  // The fallback path is taken when the primary computeLayout(node) returns
  // an empty result (rare in practice but observed in the
  // overflow tests).
}

// =============================================================================
// BAD: Genuine dead code adjacent to a prose comment still triggers
// =============================================================================

void deadCodeUnderProse() {
  // A real commented-out statement directly under a prose line must still fire:
  // the strong-code carve-out (call + parens) keeps it flagged even though the
  // block above it is prose.
  // expect_lint: prefer_no_commented_out_code
  // foo.bar();
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

  // Prose labels with colons are NOT code
  // OK: This value is allowed
  // BAD: This should not be done
  // GOOD: Preferred approach
  // LINT: Description of why this triggers
}

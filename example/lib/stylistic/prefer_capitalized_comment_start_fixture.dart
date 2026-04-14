// ignore_for_file: unused_local_variable, unused_element

/// Fixture file for prefer_capitalized_comment_start rule.
/// This rule warns when single-line comments don't start with a capital letter.
/// Commented-out code is automatically detected and skipped.

// =============================================================================
// BAD: Prose comments starting with lowercase (should trigger lint)
// =============================================================================

void badExamples() {
  // expect_lint: prefer_capitalized_comment_start
  // this is a bad comment

  // expect_lint: prefer_capitalized_comment_start
  // the user can click here to submit

  // expect_lint: prefer_capitalized_comment_start
  // note that this feature is experimental

  // expect_lint: prefer_capitalized_comment_start
  // always remember to validate input
}

// =============================================================================
// GOOD: Prose comments starting with uppercase (no lint)
// =============================================================================

void goodExamples() {
  // This is a good comment
  // The user can click here to submit
  // Note that this feature is experimental
  // Always remember to validate input
  // Check if the value is null before proceeding
}

// =============================================================================
// GOOD: Commented-out code patterns (automatically skipped)
// =============================================================================

void commentedOutCodeExamples() {
  // return value;
  // final x = 5;
  // const maxRetries = 3;
  // if (condition) {
  // for (int i = 0; i < 10; i++) {
  // while (running) {
  // switch (state) {
  // case Status.active:
  // break;
  // continue;
  // throw Exception('error');
  // try {
  // catch (e) {
  // super.initState();
  // this.value = newValue;
  // await fetchData();
  // async function
  // class MyClass {
  // enum Status {
  // import 'package:flutter/material.dart';
  // export 'src/widget.dart';
  // @override
  // @deprecated
  // foo.bar()
  // myList.add(item);
  // doSomething();
  // getValue();
  // x = 5
  // myVar = something;
  // (a, b) => a + b
  // }
  // {
}

// =============================================================================
// GOOD: Special comment markers (automatically skipped)
// =============================================================================

void specialCommentsExamples() {
  // TODO: fix this later
  // FIXME: handle edge case
  // ignore: unused_variable
  // ignore_for_file: avoid_print
  // cspell: disable-next-line
  // @param value The value to process
}

// =============================================================================
// GOOD: Doc comments are not checked (only // comments)
// =============================================================================

/// this is a doc comment and is not checked by this rule
/// because doc comments have different conventions
void docCommentExample() {}

// =============================================================================
// EDGE CASES
// =============================================================================

void edgeCases() {
  // 123 - starts with number, not lowercase letter
  // !important - starts with punctuation
  //    - empty after trim

  // expect_lint: prefer_capitalized_comment_start
  // simple prose that should be capitalized

  // URLs and file paths often look like code
  // /path/to/file.dart - starts with /
  // https://example.com - starts with protocol

  // Continuation comments on consecutive lines are NOT flagged
  // even when the second line starts with lowercase,
  // because it continues the thought from the previous line
}

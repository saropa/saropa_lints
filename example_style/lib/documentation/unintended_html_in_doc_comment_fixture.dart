// Fixture for unintended_html_in_doc_comment.

/// Bad: unintended HTML from generic type in prose.
///
/// Returns a <String> value. // expect_lint: unintended_html_in_doc_comment
void bad() {}

/// Good: use backtick-delimited code for types.
///
/// Returns a `String` value.
void good() {}

/// Good: single-letter type parameters are exempt.
///
/// Takes a <T> and returns it.
void falsePositive() {}

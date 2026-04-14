// Fixture for missing_code_block_language_in_doc_comment.

/// Bad: fenced code block without language tag.
///
/// ```
/// final x = 1;
/// ```
void bad() {} // expect_lint: missing_code_block_language_in_doc_comment

/// Good: fenced code block with language tag.
///
/// ```dart
/// final x = 1;
/// ```
void good() {}

// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: prefer_doc_comments_over_regular (v6)
// Source: lib/src/rules/stylistic/stylistic_rules.dart

// ============================================================
// BAD: Regular comment directly above public member — SHOULD trigger
// ============================================================

// expect_lint: prefer_doc_comments_over_regular
// Returns the greeting text for the user.
String greet() => 'Hello';

// expect_lint: prefer_doc_comments_over_regular
// The main entry point for processing.
void process() {}

// ============================================================
// GOOD: Should NOT trigger prefer_doc_comments_over_regular
// ============================================================

/// Already a doc comment — correct.
String docCommented() => 'ok';

// -------------------------------------------------------
// Section Header Between Dividers — should NOT trigger
// -------------------------------------------------------
void afterSectionHeader() {}

// =======================================================
// Another Section
// =======================================================
void afterAnotherSection() {}

// TODO: Implement this later
void annotatedWithTodo() {}

// FIXME: Handle edge cases
void annotatedWithFixme() {}

// NOTE: This is intentional
void annotatedWithNote() {}

// Separated by a blank line — not documentation for the member below.

void separatedByBlankLine() {}

// Private members are always skipped.
// Returns private data.
void _privateMethod() {}

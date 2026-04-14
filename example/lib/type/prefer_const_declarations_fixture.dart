// ignore_for_file: unused_element, prefer_final_locals

/// Fixture for `prefer_const_declarations` lint rule.
/// Quick fix: Replace final with const.

void placeholderPreferConstDeclarations() {
  // BAD: final with const initializer — LINT
  // expect_lint: prefer_const_declarations
  final pi = 3.14159;

  // GOOD: already const
  const greeting = 'Hello';
}

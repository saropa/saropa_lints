// ignore_for_file: unused_element, prefer_const_declarations

/// Fixture for `prefer_final_locals` lint rule.
/// Quick fix: Add final (or replace var with final).

void placeholderPreferFinalLocals() {
  // BAD: var never reassigned — LINT
  // expect_lint: prefer_final_locals
  var count = 1;

  // GOOD: final
  final name = 'ok';
}

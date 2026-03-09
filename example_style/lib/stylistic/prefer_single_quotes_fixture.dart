// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_single_quotes` lint rule.

void badExamples() {
  // LINT: Double-quoted simple string without single quotes
  final name = "John";

  // LINT: Double-quoted interpolated string without single quotes
  final greeting = "Hello, $name!";
}

void goodExamples() {
  // OK: Single-quoted string
  final name = 'John';

  // OK: Single-quoted interpolated string
  final greeting = 'Hello, $name!';

  // OK: Double-quoted string containing single quotes (SQL literal)
  final sql = "WHERE col = ''";

  // OK: Double-quoted interpolated string containing single quotes
  final col = 'status';
  final query = "WHERE $col = 'active'";

  // OK: Double-quoted string with SQL hex literal
  final hex = 'FF';
  final hexLiteral = "X'$hex'";

  // OK: Double-quoted string wrapping value in single quotes
  final escaped = 'test';
  final wrapped = "'$escaped'";

  // OK: Raw double-quoted string
  final raw = r"raw string";
}

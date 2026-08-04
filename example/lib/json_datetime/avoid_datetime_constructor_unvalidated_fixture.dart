// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_datetime_constructor_unvalidated` lint rule.

DateTime badReturnDirect(int year, int month, int day) {
  // expect_lint: avoid_datetime_constructor_unvalidated
  return DateTime(year, month, day);
}

void badPassedAsArgument(int year, int month, int day) {
  // expect_lint: avoid_datetime_constructor_unvalidated
  print(DateTime(year, month, day));
}

void badNamedParameter(int year, int month, int day) {
  // expect_lint: avoid_datetime_constructor_unvalidated
  _schedule(date: DateTime.utc(year, month, day));
}

class BadFieldInit {
  // expect_lint: avoid_datetime_constructor_unvalidated
  final DateTime date = DateTime(2026 + 1, 1, 1);
}

void goodLocalVariable(int year, int month, int day) {
  // OK — assigned to local, can validate afterward
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day) {
    throw ArgumentError('Invalid date');
  }
}

void goodLiteralsInRange() {
  // OK — all literals, all in range (parent rule allowlist)
  return _schedule(date: DateTime(2026, 6, 15));
}

void _schedule({required DateTime date}) {}

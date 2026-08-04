// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier

/// Fixture for `avoid_datetime_constructor` lint rule.

void badVariableArgs(int year, int month, int day) {
  // expect_lint: avoid_datetime_constructor
  final bad1 = DateTime(year, month, day);

  // expect_lint: avoid_datetime_constructor
  final bad2 = DateTime.utc(year, month, day);

  // expect_lint: avoid_datetime_constructor
  final lastDay = DateTime(year, month + 1, 0);

  // expect_lint: avoid_datetime_constructor
  final mixed = DateTime(2026, month, 15);
}

void badOutOfRangeLiterals() {
  // expect_lint: avoid_datetime_constructor
  final bad3 = DateTime(2026, 13, 1);

  // expect_lint: avoid_datetime_constructor
  final bad4 = DateTime(2026, 0, 1);

  // expect_lint: avoid_datetime_constructor
  final bad5 = DateTime(2026, 1, 1, 25, 0, 0);

  // expect_lint: avoid_datetime_constructor
  final bad6 = DateTime(2026, 1, 32);

  // expect_lint: avoid_datetime_constructor
  final bad7 = DateTime(2026, -1, 1);

  // expect_lint: avoid_datetime_constructor
  final bad8 = DateTime(2026, 1, 1, 0, 60);
}

void goodExamples(String dateString) {
  // OK — all literals, all in range
  final literal1 = DateTime(2026, 6, 15);

  // OK — all literals, all in range (utc)
  final literal2 = DateTime.utc(2026, 1, 1, 10, 30, 0);

  // OK — year-only (month/day default to 1)
  final yearOnly = DateTime(2026);

  // OK — day 0 idiom for "last day of previous month" (all literals)
  final lastDayFeb = DateTime(2026, 3, 0);

  // OK — tryParse returns null on invalid input
  final safe1 = DateTime.tryParse(dateString);

  // OK — parse throws on invalid input (detectable)
  final safe2 = DateTime.parse(dateString);

  // OK — DateTime.now() is a static method, not a constructor
  final now = DateTime.now();

  // OK — DateTime.fromMillisecondsSinceEpoch is a named constructor
  final epoch = DateTime.fromMillisecondsSinceEpoch(1000000);

  // OK — DateTime.fromMicrosecondsSinceEpoch
  final micro = DateTime.fromMicrosecondsSinceEpoch(1000000);
}

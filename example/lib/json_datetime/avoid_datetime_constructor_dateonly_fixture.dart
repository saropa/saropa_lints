// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier

/// Fixture for `ReplaceDateOnlyFix` — the DateUtils.dateOnly() quick fix
/// on the `avoid_datetime_constructor` rule.

/// Strip-time idiom on a non-nullable DateTime — fix SHOULD be offered.
void stripTimeGood(DateTime d) {
  // expect_lint: avoid_datetime_constructor
  final midnight = DateTime(d.year, d.month, d.day);
}

/// Explicit midnight zeros — dateOnly fix SHOULD be offered.
/// DateTime(x.year, x.month, x.day, 0, 0, 0) is equivalent to dateOnly.
void explicitMidnightZeros(DateTime d) {
  // expect_lint: avoid_datetime_constructor
  final midnight = DateTime(d.year, d.month, d.day, 0, 0, 0);
}

/// Trailing zeros with only hour — also equivalent to dateOnly.
void partialMidnightZeros(DateTime d) {
  // expect_lint: avoid_datetime_constructor
  final midnight = DateTime(d.year, d.month, d.day, 0);
}

/// Four args with non-zero hour — NOT strip-time, no dateOnly fix.
void fourArgsNonZero(DateTime d) {
  // expect_lint: avoid_datetime_constructor
  final withHour = DateTime(d.year, d.month, d.day, d.hour);
}

/// UTC constructor — DateUtils.dateOnly() returns local, not UTC.
/// No dateOnly fix should be offered.
void utcConstructor(DateTime d) {
  // expect_lint: avoid_datetime_constructor
  final utc = DateTime.utc(d.year, d.month, d.day);
}

/// Different receivers — not the same date, no dateOnly fix.
void differentReceivers(DateTime a, DateTime b, DateTime c) {
  // expect_lint: avoid_datetime_constructor
  final mixed = DateTime(a.year, b.month, c.day);
}

/// Non-DateTime type with .year/.month/.day accessors — wrong type,
/// no dateOnly fix should be offered.
void nonDateTimeType(_FakeDate holiday) {
  // expect_lint: avoid_datetime_constructor
  final midnight = DateTime(holiday.year, holiday.month, holiday.day);
}

/// Complex/null-aware args — not simple property access,
/// no dateOnly fix should be offered.
void complexArgs(DateTime? d) {
  // expect_lint: avoid_datetime_constructor
  final midnight = DateTime(d?.year ?? 0, d?.month ?? 0, d?.day ?? 0);
}

/// Nullable receiver — DateUtils.dateOnly doesn't accept DateTime?.
/// No dateOnly fix should be offered.
void nullableReceiver(DateTime? d) {
  if (d == null) return;
  // The 3-arg pattern here would still trigger the rule, but the
  // dateOnly fix must bail because d's declared type is DateTime?.
  // expect_lint: avoid_datetime_constructor
  final midnight = DateTime(d.year, d.month, d.day);
}

/// Helper class that has .year/.month/.day but is NOT DateTime.
/// Used by nonDateTimeType test above.
class _FakeDate {
  final int year;
  final int month;
  final int day;
  _FakeDate(this.year, this.month, this.day);
}

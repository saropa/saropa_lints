// ignore_for_file: unused_local_variable, unused_element, undefined_function

/// Fixture for `avoid_drift_raw_sql_interpolation` lint rule.

// NOTE: avoid_drift_raw_sql_interpolation requires Drift framework types
// and database context to trigger.
// See rule documentation for bad/good examples.

// GOOD (should NOT lint): interpolated values are constant-origin.
Future<void> _goodConstantInterpolation() async {
  const String table = 'contacts';
  for (final String column in <String>['a_text', 'b_hash']) {
    await customStatement('ALTER TABLE contacts ADD COLUMN $column TEXT');
  }
  await customStatement('DELETE FROM $table');
}

// BAD (should lint): value of unknown origin.
Future<void> _badInterpolation(String name) async {
  // expect_lint: avoid_drift_raw_sql_interpolation
  await customStatement('DROP TABLE $name');
}

// GOOD (should NOT lint): private method, every caller passes a literal.
Future<void> _addColumn(String definition) async {
  await customStatement('ALTER TABLE t ADD COLUMN $definition');
}

Future<void> _goodCallers() async {
  await _addColumn('a TEXT');
  await _addColumn('b INTEGER');
}

// BAD (should lint): one caller passes a non-literal.
Future<void> _addMixed(String definition) async {
  // expect_lint: avoid_drift_raw_sql_interpolation
  await customStatement('ALTER TABLE t ADD COLUMN $definition');
}

Future<void> _mixedCallers(String input) async {
  await _addMixed('a TEXT');
  await _addMixed(input);
}

// BAD (should lint): public method, callers unknown.
Future<void> addPublic(String definition) async {
  // expect_lint: avoid_drift_raw_sql_interpolation
  await customStatement('ALTER TABLE t ADD COLUMN $definition');
}

void main() {}

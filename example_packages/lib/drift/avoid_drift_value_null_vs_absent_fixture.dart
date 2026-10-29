// Fixture for avoid_drift_value_null_vs_absent
// ignore_for_file: unused_local_variable, depend_on_referenced_packages

// Bad examples (SHOULD trigger)
void badExamples() {}

// Good examples (should NOT trigger)
void goodExamples() {}

// Regression: Value<String?>(null) on a nullable column is the correct way to
// write SQL NULL; must NOT trigger.
void nullableValueGood() {
  const Object a = Value<String?>(null); // OK: nullable type argument
}

class Value<T> {
  const Value(this.value);
  final T value;
}

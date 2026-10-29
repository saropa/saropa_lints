// Fixture for require_drift_equals_value
// ignore_for_file: unused_local_variable, depend_on_referenced_packages

// Bad examples (SHOULD trigger)
void badExamples() {}

// Good examples (should NOT trigger)
void goodExamples() {}

// GOOD: `column.equals(Holder.someStringConst)` where the constant is a
// `static const String` (or int) is a raw SQL value, not an enum.
// BAD: `column.equals(Status.active)` where `Status` is an enum.

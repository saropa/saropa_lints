// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_firebase_transaction_for_counters` lint rule.

// BAD: Counter update without transaction
// expect_lint: prefer_firebase_transaction_for_counters
void bad() { /* doc.update({'count': count + 1}); */ }

// GOOD: Transaction for counter
void good() { /* runTransaction((t) => t.update(ref, {'count': FieldValue.increment(1)})); */ }

void main() {}

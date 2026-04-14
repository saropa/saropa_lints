// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_sqflite_reserved_words` lint rule.

// NOTE: avoid_sqflite_reserved_words fires on SQL strings with
// reserved keywords (order, group, select) as column names.
//
// BAD:
// db.execute('CREATE TABLE t (order TEXT)'); // order is reserved
//
// GOOD:
// db.execute('CREATE TABLE t ("order" TEXT)'); // quoted

void main() {}

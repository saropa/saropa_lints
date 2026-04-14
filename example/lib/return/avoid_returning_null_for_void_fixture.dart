// ignore_for_file: unused_element
// Fixture for avoid_returning_null_for_void.
// Rule flags explicit return of null in void functions.

// BAD: return null in void function — should trigger
void badReturnNullVoid() {
  return null;
}

// GOOD: no return or return; only
void goodVoid() {}

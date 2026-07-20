// ignore_for_file: unused_element, unused_local_variable
// Fixture for avoid_redundant_null_check.
// Rule flags redundant null checks on non-nullable values.

// ---------------------------------------------------------------------------
// GOOD — nullable variables: null check is valid, must NOT lint
// ---------------------------------------------------------------------------

void goodNullableParam(String? s) {
  if (s == null) return;
  print(s.length);
}

void goodNullableLocal() {
  final int? value = _maybeInt();
  if (value == null) return;
  print(value);
}

void goodNullableNotEquals(String? name) {
  if (name != null) {
    print(name);
  }
}

void goodNullableOrChain(int? a, int? b) {
  if (a == null || b == null) return;
  print(a + b);
}

void goodNullableFromMethod() {
  final String? result = _maybeString();
  if (result == null) return;
  print(result);
}

// ---------------------------------------------------------------------------
// BAD — non-nullable variables: null check is redundant, MUST lint
// ---------------------------------------------------------------------------

void badNonNullableParam(String s) {
  if (s == null) {} // LINT
}

void badNonNullableLocal() {
  final int value = 42;
  if (value == null) {} // LINT
}

void badNonNullableNotEquals(String s) {
  if (s != null) {} // LINT
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int? _maybeInt() => 1;
String? _maybeString() => 'hello';

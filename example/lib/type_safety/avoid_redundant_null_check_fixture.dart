// ignore_for_file: unused_element
// Fixture for avoid_redundant_null_check.
// Rule flags redundant null checks (e.g. after already asserting non-null).

void goodNoRedundantCheck(String? s) {
  if (s == null) return;
  print(s.length);
}

void placeholderAvoidRedundantNullCheck() {}

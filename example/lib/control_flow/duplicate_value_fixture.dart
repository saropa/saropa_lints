// Fixture for the `duplicate_value` rule: flags a sub-expression that
// appears more than once within a single &&/|| boolean expression chain.

enum Status { open, draft, closed }

class DuplicateValueBad {
  // expect_lint: duplicate_value
  bool isEditable(Status status) =>
      status == Status.open || status == Status.open;

  // expect_lint: duplicate_value
  bool bothChecksMatch(int a, int b) => a == 1 && b == 2 && a == 1;

  // expect_lint: duplicate_value
  bool sideEffectCall(int Function() getX) => getX() == 1 || getX() == 1;
}

class DuplicateValueGood {
  // Distinct comparisons on the same variable -- not a duplicate.
  bool isEditable(Status status) =>
      status == Status.open || status == Status.draft;

  // Different variables compared to the same literal -- not a duplicate.
  bool bothDistinct(int a, int b) => a == 1 && b == 1;

  // Mixed operators: the two `&&` groups are distinct opaque operands of
  // the outer `||`, so this must not be flagged as a duplicate.
  bool mixedOperators(int a, int b, int c) =>
      (a == 1 && b == 2) || (a == 1 && c == 3);
}

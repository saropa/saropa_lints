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

  // KNOWN TRADEOFF, not a bug: operands are compared by source text with no
  // purity analysis, so this deliberate skip-every-other-element idiom is
  // flagged even though the repetition is intentional -- each moveNext()
  // advances the iterator. Documented in the rule's class DartDoc; the
  // expected user response is a `// ignore: duplicate_value` with a reason.
  // expect_lint: duplicate_value
  bool skipAlternate(Iterator<int> iterator) =>
      iterator.moveNext() && iterator.moveNext();

  // Two textually identical `&&` groups joined by `||` is `x || x` -- a real
  // duplicate, and distinct from the `mixedOperators` GOOD case below where
  // the two groups merely share a fragment.
  // expect_lint: duplicate_value
  bool identicalGroups(int a, int b) => a == 1 && b == 2 || a == 1 && b == 2;

  // Regression for the paren-flattening bug: the duplicate `a == 1` is
  // split across an explicit grouping paren from the outer `||` operand,
  // but it is still the same `||` chain and must be flattened across the
  // parenthesis boundary before comparing operands.
  // expect_lint: duplicate_value
  bool parenthesizedDuplicate(int a, int b) => a == 1 || (b == 2 || a == 1);
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

  // Same-operator chain split across parentheses, but all three operands
  // are distinct once flattened -- must not be flagged.
  bool parenthesizedDistinct(int a, int b, int c) =>
      a == 1 || (b == 2 || c == 3);
}

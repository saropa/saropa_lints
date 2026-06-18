// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: avoid_cascade_shuffle
// Source: lib/src/rules/code_quality/complexity_rules.dart

// BAD: cascade shuffle on a stored reference whose result is consumed —
// permanently reorders the shared list just to read one element.
String _badVariable() {
  final List<String> masterPool = ['A', 'B', 'C'];
  // expect_lint: avoid_cascade_shuffle
  return (masterPool..shuffle()).first;
}

class _Deck {
  final List<int> cards = [1, 2, 3];

  // BAD: cascade shuffle on a field reference, result consumed.
  int top() {
    // expect_lint: avoid_cascade_shuffle
    return (cards..shuffle()).first;
  }
}

// GOOD: shuffles a throwaway copy — the source list is untouched.
String _goodCopy() {
  final List<String> masterPool = ['A', 'B', 'C'];
  return (List.of(masterPool)..shuffle()).first;
}

// GOOD: spread copy is shuffled, not the source.
String _goodSpread() {
  final List<String> masterPool = ['A', 'B', 'C'];
  return ([...masterPool]..shuffle()).first;
}

// GOOD: bare statement discards the cascade value — the in-place shuffle of
// the stored list is the deliberate intent, not a bug.
void _goodInPlace() {
  final List<String> masterPool = ['A', 'B', 'C'];
  masterPool..shuffle();
}

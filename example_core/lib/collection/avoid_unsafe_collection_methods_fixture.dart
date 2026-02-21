// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_unsafe_collection_methods` lint rule.

// BAD: Should trigger avoid_unsafe_collection_methods
// expect_lint: avoid_unsafe_collection_methods
void _bad244() {
  final items = <int>[];
  final first = items.first; // Throws StateError if empty
}

// GOOD: Should NOT trigger avoid_unsafe_collection_methods
void _good244() {
  final items = <int>[];
  final first = items.firstOrNull; // Returns null if empty — safe
}

void main() {}

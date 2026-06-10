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

// --- False-positive regression tests (bug fix) ---

// GOOD: .first guarded by length == 1 check
String _goodLengthGuard(List<String> parts) {
  if (parts.length == 1) {
    return parts.first; // Safe — length check guarantees non-empty
  }

  return parts.join(', ');
}

// GOOD: .first guarded by isNotEmpty check
String _goodIsNotEmptyGuard(List<String> parts) {
  if (parts.isNotEmpty) {
    return parts.first; // Safe — isNotEmpty guarantees non-empty
  }

  return '';
}

// GOOD (Pattern 1): combined `== null || isEmpty` early return.
Object? _goodCombinedNullOrEmpty(List<Object>? pages) {
  if (pages == null || pages.isEmpty) {
    return null;
  }
  return pages.first;
}

// GOOD (Pattern 2): `length <= 1` early return leaves length >= 2.
double _goodLengthLeOne(List<double> xs) {
  if (xs.length <= 1) {
    return 0;
  }
  return xs.first;
}

// GOOD (Pattern 3): `continue` guard inside a for loop.
List<String> _goodContinueGuard(Map<String, List<Object>> byName) {
  final List<String> out = <String>[];
  for (final List<Object> candidates in byName.values) {
    if (candidates.length != 1) {
      continue;
    }
    out.add(candidates.first.toString());
  }
  return out;
}

// GOOD (Pattern 5): map.keys.first inside a `while (map.length > n)` loop.
void _goodWhileTrim(Map<String, int> map, int maxEntries) {
  while (map.length > maxEntries) {
    final String oldest = map.keys.first;
    map.remove(oldest);
  }
}

// GOOD (Pattern 8): split() result accessed through a local variable.
String _goodSplitViaVariable(String prefix) {
  final List<String> parts = prefix.split(';');
  return parts.first;
}

void main() {}

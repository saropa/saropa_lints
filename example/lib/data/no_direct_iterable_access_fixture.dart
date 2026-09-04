// ignore_for_file: unused_element

/// Fixtures for no_direct_iterable_access.
library;

// =============================================================================
// BAD: direct `list[index]` access with no bounds guarantee
// =============================================================================

String _firstItemLabel(List<String> items) {
  // expect_lint: no_direct_iterable_access
  return items[0];
}

int _elementAt(List<int> values, int offset) {
  // expect_lint: no_direct_iterable_access
  return values[offset];
}

// =============================================================================
// GOOD: bounds-safe accessor with an explicit fallback
// =============================================================================

String _firstItemLabelSafe(List<String> items) {
  // firstOrNull is a dart:core Iterable extension (no package:collection
  // dependency required), unlike elementAtOrNull which lives in
  // package:collection — kept dependency-free for this fixture.
  return items.firstOrNull ?? '';
}

// =============================================================================
// GOOD near-miss: index access immediately guarded by an explicit
// `index < list.length` bounds check (edge case 1 — developer already
// guarded the access)
// =============================================================================

int? _guardedElementAt(List<int> values, int index) {
  if (index < values.length) {
    return values[index];
  }
  return null;
}

// =============================================================================
// GOOD near-miss: index access inside a `for` loop whose condition provably
// bounds the loop variable (edge case 2)
// =============================================================================

void _printAll(List<String> items) {
  for (var i = 0; i < items.length; i++) {
    print(items[i]);
  }
}

// =============================================================================
// GOOD near-miss: constant list literal with a constant, in-range index
// (edge case 3 — statically provable safety)
// =============================================================================

const int _constantSecond = [1, 2, 3][1];

// =============================================================================
// GOOD near-miss: Map bracket access is out of scope — Map's [] returns
// null on a miss rather than throwing (edge case 4)
// =============================================================================

String? _lookup(Map<String, String> map, String key) {
  return map[key];
}

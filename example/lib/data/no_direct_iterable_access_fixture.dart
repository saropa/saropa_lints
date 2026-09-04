// ignore_for_file: unused_element

/// Fixtures for no_direct_iterable_access.
library;

import 'dart:typed_data';

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

// Regression for the fixed `<=` guard bug: `index <= values.length` still
// allows `index == values.length`, which throws — must still fire.
int _offByOneGuard(List<int> values, int index) {
  if (index <= values.length) {
    // expect_lint: no_direct_iterable_access
    return values[index];
  }
  return -1;
}

// Typed-data lists (Uint8List, Float64List, ...) `extends List<int>`/
// `List<double>` and throw the identical RangeError on out-of-bounds `[]`,
// so they must be in scope too (concern: isDartCoreList exact-type check
// previously missed List-shaped subtypes).
int _firstByte(Uint8List bytes) {
  // expect_lint: no_direct_iterable_access
  return bytes[0];
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
// GOOD near-miss: reversed comparison operand order — `list.length > index`
// is the same guard as `index < list.length` (issue 5)
// =============================================================================

int? _guardedElementAtReversed(List<int> values, int index) {
  if (values.length > index) {
    return values[index];
  }
  return null;
}

// =============================================================================
// GOOD near-miss: early-return guard clause — the most common real-world
// idiom, distinct from the nested-if form above (issue 3)
// =============================================================================

int _elementAtWithEarlyReturn(List<int> values, int index) {
  if (index >= values.length) return -1;
  return values[index];
}

// =============================================================================
// GOOD near-miss: `else`-branch guard — the access runs only when the
// unsafe condition was false (issue 4)
// =============================================================================

int _elementAtWithElseGuard(List<int> values, int index) {
  if (index >= values.length) {
    return -1;
  } else {
    return values[index];
  }
}

// =============================================================================
// GOOD near-miss: explicit `RangeError.checkValidIndex` guard — dart:core's
// own recommended way to validate an index (opportunity)
// =============================================================================

int _elementAtWithRangeErrorCheck(List<int> values, int index) {
  RangeError.checkValidIndex(index, values);
  return values[index];
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
// GOOD near-miss: index access inside a collection-literal `for` element
// whose condition provably bounds the loop variable (concern: ForElement)
// =============================================================================

List<String> _copyAll(List<String> items) {
  return [for (var i = 0; i < items.length; i++) items[i]];
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

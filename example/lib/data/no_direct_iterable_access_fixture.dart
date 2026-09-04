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
// GOOD near-miss: `isNotEmpty` guard around a literal `[0]` access — the most
// common bounds-guard idiom in Dart, and a getter access rather than a
// comparison, so it must be recognized without a BinaryExpression
// =============================================================================

int? _firstWhenNotEmpty(List<int> values) {
  if (values.isNotEmpty) {
    return values[0];
  }
  return null;
}

// =============================================================================
// GOOD near-miss: `isEmpty` early-return guard — the mirror image of the
// isNotEmpty form; every statement after it runs on a non-empty list
// =============================================================================

int _firstWithEmptyEarlyReturn(List<int> values) {
  if (values.isEmpty) return -1;
  return values[0];
}

// =============================================================================
// BAD near-miss for the emptiness guards: `isNotEmpty` only proves
// `length >= 1`, so it makes ONLY index 0 safe — an arbitrary index can still
// throw and must still be flagged
// =============================================================================

int? _nthWhenNotEmpty(List<int> values, int index) {
  if (values.isNotEmpty) {
    // expect_lint: no_direct_iterable_access
    return values[index];
  }
  return null;
}

// =============================================================================
// GOOD near-miss: ternary guards — the same conditions written as an
// expression body, in both branch orientations
// =============================================================================

int _firstViaEmptyTernary(List<int> v) => v.isEmpty ? -1 : v[0];

int _firstViaLengthTernary(List<int> v) => v.length > 0 ? v[0] : -1;

// =============================================================================
// BAD near-miss for the ternary guard: branches inverted, so the access runs
// exactly when the list IS empty — a real crash
// =============================================================================

// expect_lint: no_direct_iterable_access
int _firstViaInvertedTernary(List<int> v) => v.isEmpty ? v[0] : -1;

// =============================================================================
// GOOD near-miss: `while` / `do-while` loops bounded by `list.length` — the
// hand-rolled cursor loop, previously unrecognized because only `for` forms
// were inspected
// =============================================================================

void _printAllWhile(List<String> items) {
  var i = 0;
  while (i < items.length) {
    print(items[i]);
    i++;
  }
}

void _printAllDoWhile(List<String> items) {
  var i = 0;
  do {
    print(items[i]);
    i++;
  } while (i < items.length);
}

// =============================================================================
// BAD near-miss for the while guard: the loop bound is on a DIFFERENT list,
// so it proves nothing about `items`
// =============================================================================

void _printAllWhileWrongBound(List<String> items, List<String> other) {
  var i = 0;
  while (i < other.length) {
    // expect_lint: no_direct_iterable_access
    print(items[i]);
    i++;
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

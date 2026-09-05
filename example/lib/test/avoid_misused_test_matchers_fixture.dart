// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: unnecessary_lambdas, dead_code, unreachable_from_main

/// Fixture for `avoid_misused_test_matchers` lint rule.
///
/// BAD examples use raw literals as expect() matchers.
/// GOOD examples use proper test matcher functions.

// Simulated test API so the fixture compiles without package:test.
void expect(Object? actual, Object? matcher) {}

const isTrue = _Matcher();
const isFalse = _Matcher();
const isNull = _Matcher();

_Matcher hasLength(int n) => _Matcher();

class _Matcher {
  const _Matcher();
}

// ---------------------------------------------------------------------------
// BAD: Raw boolean literals as matchers
// ---------------------------------------------------------------------------

void badBoolLiterals() {
  final result = true;

  // LINT
  expect(result, true);

  // LINT
  expect(result, false);
}

// ---------------------------------------------------------------------------
// BAD: Raw null literal as matcher
// ---------------------------------------------------------------------------

void badNullLiteral() {
  final value = null;

  // LINT
  expect(value, null);
}

// ---------------------------------------------------------------------------
// BAD: Raw integer literal with .length access
// ---------------------------------------------------------------------------

void badLengthLiteral() {
  final list = [1, 2, 3];

  // LINT
  expect(list.length, 3);
}

// ---------------------------------------------------------------------------
// GOOD: Proper matcher functions
// ---------------------------------------------------------------------------

void goodMatchers() {
  final result = true;
  final value = null;
  final list = [1, 2, 3];

  // Proper boolean matchers
  expect(result, isTrue);
  expect(result, isFalse);

  // Proper null matcher
  expect(value, isNull);

  // Proper length matcher
  expect(list, hasLength(3));
}

// Test fixture for avoid_duplicate_*_elements rules
// Tests: avoid_duplicate_number_elements, avoid_duplicate_string_elements,
//        avoid_duplicate_object_elements

// ignore_for_file: prefer_const_declarations, unused_local_variable
// ignore_for_file: prefer_final_locals

// =============================================================================
// avoid_duplicate_number_elements
// =============================================================================

/// Duplicate integers - SHOULD trigger
void duplicateIntegersExample() {
  // LINT: 1 is duplicated
  final list = [1, 2, 1, 3];

  // LINT: 42 is duplicated
  final numbers = [42, 10, 42, 20];
}

/// Duplicate doubles - SHOULD trigger
void duplicateDoublesExample() {
  // LINT: 1.5 is duplicated
  final prices = [1.5, 2.0, 1.5, 3.0];

  // LINT: 9.99 is duplicated
  final costs = [9.99, 19.99, 9.99];
}

/// Duplicate numbers in sets - SHOULD trigger
void duplicateNumbersInSetExample() {
  // LINT: 5 is duplicated (set will silently ignore)
  final uniqueIds = {1, 2, 5, 3, 5};
}

/// Legitimate use case - suppress for days-in-month
void legitimateDuplicateNumbers() {
  // ignore: avoid_duplicate_number_elements
  const List<int> daysInMonth = <int>[
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
}

/// No duplicates - should NOT trigger
void noDuplicateNumbersExample() {
  final list = [1, 2, 3, 4, 5]; // OK: All unique
  final prices = [9.99, 19.99, 29.99]; // OK: All unique
}

// =============================================================================
// avoid_duplicate_string_elements
// =============================================================================

/// Duplicate strings - SHOULD trigger
void duplicateStringsExample() {
  // LINT: 'a' is duplicated
  final letters = ['a', 'b', 'a', 'c'];

  // LINT: 'hello' is duplicated
  final greetings = ['hello', 'world', 'hello'];
}

/// Duplicate strings in sets - SHOULD trigger
void duplicateStringsInSetExample() {
  // LINT: 'admin' is duplicated
  final roles = {'admin', 'user', 'admin', 'guest'};
}

/// URLs with duplicates - SHOULD trigger
void duplicateUrlsExample() {
  // LINT: URL is duplicated
  final endpoints = [
    'https://api.example.com/v1',
    'https://api.example.com/v2',
    'https://api.example.com/v1',
  ];
}

/// No duplicates - should NOT trigger
void noDuplicateStringsExample() {
  final list = ['a', 'b', 'c']; // OK: All unique
  final words = ['hello', 'world', 'foo']; // OK: All unique
}

// =============================================================================
// avoid_duplicate_object_elements
// =============================================================================

/// Duplicate booleans - SHOULD trigger
void duplicateBooleansExample() {
  // LINT: true is duplicated
  final flags = [true, false, true];

  // LINT: false is duplicated
  final checks = [false, true, false, false];
}

/// Duplicate nulls - SHOULD trigger
void duplicateNullsExample() {
  // LINT: null is duplicated
  final maybeValues = [null, 'value', null];
}

/// Duplicate identifiers - SHOULD trigger
void duplicateIdentifiersExample() {
  final myObj = Object();
  final otherObj = Object();

  // LINT: myObj is duplicated
  final objects = [myObj, otherObj, myObj];
}

/// No duplicates - should NOT trigger
void noDuplicateObjectsExample() {
  final a = Object();
  final b = Object();
  final c = Object();

  final objects = [a, b, c]; // OK: All unique
  final bools = [true, false]; // OK: All unique
}

// =============================================================================
// Mixed collections - each rule handles its own type
// =============================================================================

/// Mixed types - each rule only handles its own type
void mixedTypesExample() {
  // LINT (number): 1 is duplicated
  // LINT (string): 'a' is duplicated
  // LINT (object): true is duplicated
  final mixed = [1, 'a', true, 1, 'a', true];
}

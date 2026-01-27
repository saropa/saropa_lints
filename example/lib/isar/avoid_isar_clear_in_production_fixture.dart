// Test fixture for AvoidIsarClearInProductionRule
// Tests that the rule only flags Isar.clear(), not Map/List/Set/etc.

// ignore_for_file: unused_local_variable, unused_element

// =============================================================================
// avoid_isar_clear_in_production
// =============================================================================

// BAD: Isar.clear() without a debug guard
Future<void> testIsarClearUnguarded(Isar isar) async {
  // expect_lint: avoid_isar_clear_in_production
  await isar.clear();
}

// GOOD: Isar.clear() inside a kDebugMode guard
Future<void> testIsarClearGuarded(Isar isar) async {
  if (kDebugMode) {
    await isar.clear();
  }
}

// GOOD: Map.clear() must NOT trigger (false positive regression)
void testMapClear() {
  final Map<String, List<String>> cache = <String, List<String>>{};
  cache.clear();
}

// GOOD: List.clear() must NOT trigger (false positive regression)
void testListClear() {
  final List<int> items = <int>[1, 2, 3];
  items.clear();
}

// GOOD: Set.clear() must NOT trigger (false positive regression)
void testSetClear() {
  final Set<String> tags = <String>{'a', 'b'};
  tags.clear();
}

// GOOD: StringBuffer.clear() must NOT trigger (false positive regression)
void testStringBufferClear() {
  final StringBuffer buffer = StringBuffer('hello');
  buffer.clear();
}

// =============================================================================
// Mock types (for static type resolution without package:isar dependency)
// =============================================================================

class Isar {
  Future<void> clear() async {}
}

const bool kDebugMode = true;

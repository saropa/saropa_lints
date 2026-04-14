// ignore_for_file: unused_element
// Test fixture for: prefer_asmap_over_indexed_iteration
// BAD: manual index loop
// expect_lint: prefer_asmap_over_indexed_iteration
void bad() {
  final list = ['a', 'b'];
  for (var i = 0; i < list.length; i++) {
    print(list[i]);
  }
}

// GOOD: asMap().entries
void good() {
  final list = ['a', 'b'];
  for (final e in list.asMap().entries) {
    print('${e.key}: ${e.value}');
  }
}

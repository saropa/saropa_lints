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

// GOOD: pairwise scan - the inner start depends on the outer index.
void goodPairwise(List<int> l) {
  for (int i = 0; i < l.length; i++) {
    for (int j = i + 1; j < l.length; j++) {
      print(l[i] + l[j]);
    }
  }
}

// GOOD: the index also addresses a second collection.
void goodSecondCollection(List<int> a, List<int> b) {
  for (int j = 0; j < a.length; j++) {
    print(a[j] + b[j]);
  }
}

// GOOD: the iterated list grows during the loop (BFS).
void goodGrowingList(List<int> seed) {
  final group = <int>[...seed];
  for (int i = 0; i < group.length; i++) {
    group.addAll(<int>[group[i] + 1]);
  }
}

// BAD: near miss - mutates a different list, one indexed target.
// expect_lint: prefer_asmap_over_indexed_iteration
void badMutatesOther(List<int> a, List<int> out) {
  for (int i = 0; i < a.length; i++) {
    out.add(a[i]);
  }
}

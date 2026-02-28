// ignore_for_file: unused_element, unused_local_variable, depend_on_referenced_packages
// Fixture for require_pagination_for_large_lists rule.

import 'package:flutter/material.dart';

// ============ BAD: itemCount from bulk-style list name (should trigger) ============

// LINT: require_pagination_for_large_lists
Widget buildProductListBad(List<dynamic> allProducts) {
  return ListView.builder(
    itemCount: allProducts.length,
    itemBuilder: (context, i) => ListTile(title: Text('${allProducts[i]}')),
  );
}

// ============ GOOD: variable name not in bulk heuristic (should NOT trigger) ============

Widget buildCategoryListGood(List<dynamic> categories) {
  return ListView.builder(
    itemCount: categories.length,
    itemBuilder: (context, i) => ListTile(title: Text('${categories[i]}')),
  );
}

// ============ GOOD: small fixed count (should NOT trigger) ============

Widget buildFixedListGood() {
  return ListView.builder(
    itemCount: 5,
    itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
  );
}

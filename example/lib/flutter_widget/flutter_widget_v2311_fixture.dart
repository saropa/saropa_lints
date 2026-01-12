// ignore_for_file: unused_local_variable, unused_element
// Test fixture for flutter widget rules added in v2.3.11

// =========================================================================
// avoid_builder_index_out_of_bounds
// =========================================================================
// Warns when itemBuilder accesses list without bounds check.
// If the list changes while the builder is running, index may be invalid.

import 'package:flutter/widgets.dart';

// BAD: No bounds check on list access
class BadListBuilderNoBoundsCheck extends StatelessWidget {
  const BadListBuilderNoBoundsCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, index) {
        return Text(items[index]); // items might change!
      },
    );
  }
}

// BAD: Using 'i' as index without bounds check
class BadListBuilderIVariable extends StatelessWidget {
  const BadListBuilderIVariable({super.key, required this.data});
  final List<int> data;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: data.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, i) {
        return Text('${data[i]}'); // data might change!
      },
    );
  }
}

// GOOD: With bounds check
class GoodListBuilderWithBoundsCheck extends StatelessWidget {
  const GoodListBuilderWithBoundsCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (index >= items.length) return const SizedBox.shrink();
        return Text(items[index]); // Safe - bounds checked
      },
    );
  }
}

// GOOD: Using isEmpty check
class GoodListBuilderIsEmptyCheck extends StatelessWidget {
  const GoodListBuilderIsEmptyCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Text(items[index]);
      },
    );
  }
}

// GOOD: No list access in itemBuilder (safe)
class GoodListBuilderNoAccess extends StatelessWidget {
  const GoodListBuilderNoAccess({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Text('Item $index'); // No list access
      },
    );
  }
}

// GOOD: Using isNotEmpty check
class GoodListBuilderIsNotEmptyCheck extends StatelessWidget {
  const GoodListBuilderIsNotEmptyCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (items.isNotEmpty && index < items.length) {
          return Text(items[index]);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// BAD: Bounds check on WRONG list - should be caught!
class BadListBuilderWrongListCheck extends StatelessWidget {
  const BadListBuilderWrongListCheck({
    super.key,
    required this.items,
    required this.otherList,
  });
  final List<String> items;
  final List<String> otherList;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, index) {
        // Bounds check on otherList, but accessing items!
        if (otherList.length > 0) {
          return Text(items[index]); // WRONG - items not checked!
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// GOOD: Property access with correct bounds check
class GoodListBuilderPropertyAccess extends StatelessWidget {
  const GoodListBuilderPropertyAccess({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (index >= items.length) return const SizedBox.shrink();
        return Text(items[index]); // Safe - correct list checked
      },
    );
  }
}

// BAD: Multiple lists accessed, only one checked
class BadListBuilderMultipleLists extends StatelessWidget {
  const BadListBuilderMultipleLists({
    super.key,
    required this.names,
    required this.ages,
  });
  final List<String> names;
  final List<int> ages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: names.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, index) {
        // Only names is checked, but ages is also accessed
        if (index >= names.length) return const SizedBox.shrink();
        return Text('${names[index]}: ${ages[index]}'); // ages not checked!
      },
    );
  }
}

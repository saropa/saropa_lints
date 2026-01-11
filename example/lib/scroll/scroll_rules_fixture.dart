// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
// Test fixture for scroll and list rules

import '../flutter_mocks.dart';

// =========================================================================
// avoid_shrinkwrap_in_scrollview
// =========================================================================

// Moved to dedicated test - this widget triggers both shrinkwrap and nested rules
// which makes expect_lint testing complex. See scroll_rules_shrinkwrap_test.dart

class BadNestedScrollOnlyWidget extends StatelessWidget {
  const BadNestedScrollOnlyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // This ListView is nested without physics - triggers conflict rule
          // expect_lint: avoid_nested_scrollables_conflict
          ListView(
            children: [Text('Item 1'), Text('Item 2')],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// avoid_nested_scrollables_conflict
// =========================================================================

class BadNestedScrollWidget extends StatelessWidget {
  const BadNestedScrollWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // expect_lint: avoid_nested_scrollables_conflict
          ListView(
            // expect_lint: avoid_shrinkwrap_in_scrollview
            shrinkWrap: true,
            children: [Text('Item 1')],
          ),
        ],
      ),
    );
  }
}

// GOOD: Nested scrollable with explicit physics
class GoodNestedScrollWidget extends StatelessWidget {
  const GoodNestedScrollWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [Text('Item 1')],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// avoid_listview_children_for_large_lists
// =========================================================================

class BadLargeListWidget extends StatelessWidget {
  const BadLargeListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Note: This rule only detects literal lists, not List.generate
    return ListView(
      children: List.generate(50, (i) => Text('Item $i')),
    );
  }
}

// GOOD: Use ListView.builder for large lists
class GoodLargeListWidget extends StatelessWidget {
  const GoodLargeListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 50,
      itemBuilder: (_, i) => Text('Item $i'),
    );
  }
}

// =========================================================================
// avoid_excessive_bottom_nav_items
// =========================================================================

class BadBottomNavWidget extends StatelessWidget {
  const BadBottomNavWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      // expect_lint: avoid_excessive_bottom_nav_items
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        BottomNavigationBarItem(icon: Icon(Icons.help), label: 'Help'),
      ],
    );
  }
}

// =========================================================================
// avoid_multiple_autofocus
// =========================================================================

class BadMultipleAutofocusWidget extends StatelessWidget {
  const BadMultipleAutofocusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(autofocus: true),
        // expect_lint: avoid_multiple_autofocus
        TextField(autofocus: true),
      ],
    );
  }
}

// =========================================================================
// avoid_shrink_wrap_expensive (new in 2.3.7)
// =========================================================================

class BadShrinkWrapExpensiveWidget extends StatelessWidget {
  const BadShrinkWrapExpensiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // BAD: shrinkWrap is expensive for large lists
    return ListView.builder(
      // expect_lint: avoid_shrink_wrap_expensive
      shrinkWrap: true,
      itemCount: 100,
      itemBuilder: (_, i) => Text('Item $i'),
    );
  }
}

// =========================================================================
// prefer_item_extent (new in 2.3.7)
// =========================================================================

class BadNoItemExtentWidget extends StatelessWidget {
  const BadNoItemExtentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // BAD: itemExtent missing for uniform items
    // expect_lint: prefer_item_extent
    return ListView.builder(
      itemCount: 100,
      itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Item $i')),
    );
  }
}

// GOOD: Using itemExtent for uniform items
class GoodItemExtentWidget extends StatelessWidget {
  const GoodItemExtentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 100,
      itemExtent: 50.0,
      itemBuilder: (_, i) => Text('Item $i'),
    );
  }
}

// =========================================================================
// require_key_for_reorderable (new in 2.3.7)
// =========================================================================

class BadReorderableWidget extends StatelessWidget {
  const BadReorderableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // BAD: ReorderableListView children without keys
    return ReorderableListView(
      onReorder: (oldIndex, newIndex) {},
      // expect_lint: require_key_for_reorderable
      children: [
        Text('Item 1'),
        Text('Item 2'),
        Text('Item 3'),
      ],
    );
  }
}

// GOOD: ReorderableListView with keys
class GoodReorderableWidget extends StatelessWidget {
  const GoodReorderableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      onReorder: (oldIndex, newIndex) {},
      children: [
        Text('Item 1', key: ValueKey('1')),
        Text('Item 2', key: ValueKey('2')),
        Text('Item 3', key: ValueKey('3')),
      ],
    );
  }
}

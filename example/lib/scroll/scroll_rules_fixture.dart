// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
// Test fixture for scroll and list rules

import 'package:flutter/material.dart';

// =========================================================================
// avoid_shrinkwrap_in_scrollview
// =========================================================================

class BadShrinkWrapWidget extends StatelessWidget {
  const BadShrinkWrapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // expect_lint: avoid_shrinkwrap_in_scrollview
          ListView(
            shrinkWrap: true,
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
    // expect_lint: avoid_listview_children_for_large_lists
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
    // expect_lint: avoid_excessive_bottom_nav_items
    return BottomNavigationBar(
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
        // expect_lint: avoid_multiple_autofocus
        TextField(autofocus: true),
        // expect_lint: avoid_multiple_autofocus
        TextField(autofocus: true),
      ],
    );
  }
}

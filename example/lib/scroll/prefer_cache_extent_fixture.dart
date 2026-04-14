// ignore_for_file: unused_local_variable, unused_element

import 'package:flutter/material.dart';

/// Fixture for `prefer_cache_extent` lint rule.
///
/// BAD: ListView.builder / GridView.builder without cacheExtent (should trigger).
/// GOOD: With cacheExtent, or non-builder constructors (should not trigger).

void badListViewBuilder(BuildContext context) {
  // LINT: prefer_cache_extent
  final bad = ListView.builder(
    itemCount: 100,
    itemBuilder: (context, i) => ListTile(title: Text('$i')),
  );
}

void badListViewSeparated(BuildContext context) {
  // LINT: prefer_cache_extent
  final bad = ListView.separated(
    itemCount: 50,
    separatorBuilder: (_, __) => const Divider(),
    itemBuilder: (context, i) => ListTile(title: Text('$i')),
  );
}

void badGridViewBuilder(BuildContext context) {
  // LINT: prefer_cache_extent
  final bad = GridView.builder(
    gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
    itemCount: 100,
    itemBuilder: (context, i) => ListTile(title: Text('$i')),
  );
}

void goodWithCacheExtent(BuildContext context) {
  // OK: cacheExtent specified
  final good = ListView.builder(
    itemCount: 100,
    cacheExtent: 500,
    itemBuilder: (context, i) => ListTile(title: Text('$i')),
  );
}

void goodDefaultConstructor() {
  // OK: default constructor (not builder/separated) — rule does not apply
  final good = ListView(children: const [Text('a')]);
}

void goodGridViewCount() {
  // OK: GridView.count is not .builder — rule does not apply
  final good = GridView.count(
    crossAxisCount: 2,
    children: List.generate(10, (i) => ListTile(title: Text('$i'))),
  );
}

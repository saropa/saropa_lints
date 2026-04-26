// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors

/// Fixture for `prefer_const_literals_to_create_immutables` lint rule.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Non-const list passed to immutable
// expect_lint: prefer_const_literals_to_create_immutables
Widget bad() => Column(children: [const Text('a')]);

// GOOD: Const literal
Widget good() => Column(children: const [Text('a')]);

// GOOD: Parent constructor is `const`, so the inner literal is auto-promoted
// by the language. Adding an explicit `const` here would be redundant and
// trigger the standard analyzer's `unnecessary_const`.
Widget goodConstParent() => const Column(children: [Text('a')]);

// GOOD: Same as above with an already-explicit const on the literal.
Widget goodConstParentAndLiteral() =>
    const Column(children: const [Text('a')]);

// GOOD: const context propagates through nested const constructors. The
// Column has no explicit `const` keyword, but it inherits a const context
// from `const Padding(...)`, so its children list is auto-promoted.
Widget goodConstContextPropagation() => const Padding(
  padding: EdgeInsets.all(0),
  child: Column(children: [Text('a')]),
);

void main() {}

// Fixture to test the arguments_ordering rule.
//
// This rule enforces alphabetical ordering of named arguments in function calls.
//
// Quick fix available: "Sort arguments alphabetically"

// ignore_for_file: unused_local_variable, prefer_const_constructors

import '../flutter_mocks.dart';

// Example function with named parameters
void exampleFunction({
  required String alpha,
  required String beta,
  required String gamma,
}) {}

// Example class with named parameters
class ExampleWidget {
  const ExampleWidget({
    required this.alpha,
    required this.beta,
    required this.gamma,
  });

  final String alpha;
  final String beta;
  final String gamma;
}

void goodExamples() {
  // GOOD: Named arguments in alphabetical order
  exampleFunction(
    alpha: 'first',
    beta: 'second',
    gamma: 'third',
  );

  // GOOD: Named arguments in alphabetical order
  final widget = ExampleWidget(
    alpha: 'a',
    beta: 'b',
    gamma: 'c',
  );

  // GOOD: Single named argument (nothing to order)
  exampleFunction(
    alpha: 'only',
    beta: 'b',
    gamma: 'c',
  );
}

void badExamples() {
  // expect_lint: arguments_ordering
  exampleFunction(
    gamma: 'third',
    beta: 'second',
    alpha: 'first',
  );

  // expect_lint: arguments_ordering
  final widget = ExampleWidget(
    gamma: 'c',
    alpha: 'a',
    beta: 'b',
  );

  // expect_lint: arguments_ordering
  exampleFunction(
    beta: 'second',
    alpha: 'first',
    gamma: 'third',
  );
}

void mixedPositionalAndNamedExamples() {
  // Example with positional and named arguments
  void mixedFunction(String positional, {required String alpha, required String beta}) {}

  // GOOD: Named arguments alphabetically ordered after positional
  mixedFunction(
    'positional',
    alpha: 'a',
    beta: 'b',
  );

  // expect_lint: arguments_ordering
  mixedFunction(
    'positional',
    beta: 'b',
    alpha: 'a',
  );
}

void flutterStyleExamples() {
  // Common Flutter pattern - Container with many named arguments
  // GOOD: Alphabetically ordered
  final goodContainer = Container(
    alignment: Alignment.center,
    child: Text('Hello'),
    color: Colors.blue,
    height: 100,
    padding: EdgeInsets.all(8),
    width: 200,
  );

  // expect_lint: arguments_ordering
  final badContainer = Container(
    width: 200,
    height: 100,
    color: Colors.blue,
    child: Text('Hello'),
    alignment: Alignment.center,
    padding: EdgeInsets.all(8),
  );
}

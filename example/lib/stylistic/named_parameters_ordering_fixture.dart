// Fixture to test the named_parameters_ordering rule.
//
// This rule enforces that named arguments at a call site keep the same
// relative order as the named parameters in the invoked declaration.
// It is distinct from `arguments_ordering`, which enforces alphabetical
// order regardless of declaration order.

// ignore_for_file: unused_local_variable, prefer_const_constructors

// Example class with named parameters declared host, port, timeout.
class Config {
  const Config({required this.host, required this.port, this.timeout});

  final String host;
  final int port;
  final int? timeout;
}

// Example function whose named parameters are declared alpha, beta, gamma —
// deliberately NOT alphabetical, to prove this rule follows DECLARATION
// order rather than sorting (that is the `arguments_ordering` rule's job).
void exampleFunction({
  required String gamma,
  required String alpha,
  required String beta,
}) {}

void goodExamples() {
  // GOOD: matches declaration order (host, port, timeout).
  const Config(host: 'example.com', port: 443, timeout: 5);

  // GOOD: a trailing parameter omitted; the two present args still keep
  // their declared relative order (host before port).
  const Config(host: 'example.com', port: 443);

  // GOOD: matches declaration order (gamma, alpha, beta) even though that
  // is not alphabetical — proves this rule does not sort alphabetically.
  exampleFunction(gamma: 'g', alpha: 'a', beta: 'b');

  // GOOD near-miss: only one named argument present — nothing to order.
  const Config(host: 'example.com');
}

void badExamples() {
  // expect_lint: named_parameters_ordering
  const Config(port: 443, host: 'example.com');

  // expect_lint: named_parameters_ordering
  const Config(timeout: 5, host: 'example.com', port: 443);

  // expect_lint: named_parameters_ordering
  exampleFunction(alpha: 'a', gamma: 'g', beta: 'b');
}

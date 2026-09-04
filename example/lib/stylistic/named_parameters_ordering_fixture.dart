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

// Edge case 4 (proposal doc): named parameters interleaved with a leading
// positional parameter. Positional args never enter the named-arg index
// space, so `label` participates in neither the good nor the bad ordering.
void exampleMixedFunction(
  String label, {
  required String alpha,
  required String beta,
}) {}

// Declared purely to be torn off / assigned to a variable below, so the
// call site below resolves as a `FunctionExpressionInvocation` rather than
// a `MethodInvocation` — a distinct AST node the rule only recently gained
// a hook for.
void exampleAlphaBetaFunction({required String alpha, required String beta}) {}

// Enum whose constant declarations invoke a named-parameter constructor —
// `EnumConstantDeclaration` is a distinct AST node from
// `InstanceCreationExpression` with its own (recently added) hook.
enum ExampleEnum {
  good(alpha: 'a', beta: 'b'),

  // expect_lint: named_parameters_ordering
  bad(beta: 'b', alpha: 'a');

  const ExampleEnum({required this.alpha, required this.beta});

  final String alpha;
  final String beta;
}

// Edge case 2 (proposal doc): a subclass constructor forwarding to `super`
// with its named arguments reordered relative to the base constructor's
// declaration. `SuperConstructorInvocation` has no visitor hook anywhere in
// `SaropaContext` yet (a framework gap, not something this rule can fix
// alone — see the Finish Report), so this is a DOCUMENTED false negative:
// the reorder below is exactly the kind of mistake this rule exists to
// catch, but it will not fire here until that framework hook is added.
class ConfigSubclass extends Config {
  ConfigSubclass(String host, int port) : super(port: port, host: host);
}

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

  // GOOD: edge case 4 — positional `label` interleaved with named args that
  // themselves keep declaration order (alpha before beta).
  exampleMixedFunction('x', alpha: 'a', beta: 'b');

  // GOOD: FunctionExpressionInvocation call site (`fn(...)` where `fn` is a
  // function-typed variable, not the function's own name) with named args
  // in declaration order.
  final void Function({required String alpha, required String beta}) fn =
      exampleAlphaBetaFunction;
  fn(alpha: 'a', beta: 'b');
}

void badExamples() {
  // expect_lint: named_parameters_ordering
  const Config(port: 443, host: 'example.com');

  // expect_lint: named_parameters_ordering
  const Config(timeout: 5, host: 'example.com', port: 443);

  // expect_lint: named_parameters_ordering
  exampleFunction(alpha: 'a', gamma: 'g', beta: 'b');

  // expect_lint: named_parameters_ordering
  // Edge case 4, bad variant: named args reordered (beta before alpha)
  // while the leading positional `label` argument is unaffected.
  exampleMixedFunction('x', beta: 'b', alpha: 'a');

  // expect_lint: named_parameters_ordering
  // FunctionExpressionInvocation call site with reordered named args —
  // proves the rule now checks this AST node, not just MethodInvocation.
  final void Function({required String alpha, required String beta}) fn =
      exampleAlphaBetaFunction;
  fn(beta: 'b', alpha: 'a');
}

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
// declaration. `SaropaContext` exposes no `addSuperConstructorInvocation`
// hook, so the rule reaches this node via `addConstructorDeclaration` and
// walks the initializer list — this used to be a documented false negative
// and is now covered.
class ConfigSubclass extends Config {
  // expect_lint: named_parameters_ordering
  ConfigSubclass(String host, int port) : super(port: port, host: host);
}

// GOOD counterpart: the same forwarding pattern with the super arguments in
// the base constructor's declared order (host before port) must stay silent.
class ConfigSubclassGood extends Config {
  ConfigSubclassGood(String host, int port) : super(host: host, port: port);
}

// Redirecting generative constructor (`: this(...)`) is the other initializer
// form the same hook covers — same AST position, different node type.
class RedirectTarget {
  RedirectTarget({required this.alpha, required this.beta});

  // expect_lint: named_parameters_ordering
  RedirectTarget.reordered(String a, String b) : this(beta: b, alpha: a);

  final String alpha;
  final String beta;
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
  // in declaration order. Note this stays silent for the trivial reason that
  // the rule cannot resolve such callees at all — see the false-negative note
  // in badExamples() below.
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

  // DOCUMENTED FALSE NEGATIVE — deliberately carries NO expect_lint marker.
  // This is a FunctionExpressionInvocation with reordered named args, and the
  // rule does register a hook for that node type, but
  // `FunctionExpressionInvocation.element` is null when the callee is a
  // function-TYPED variable (there is no ExecutableElement to read a declared
  // parameter order from), so `_checkOrder` bails immediately. The declared
  // order is only reachable via `staticInvokeType`, which the rule does not
  // consult. Pinned by the "documented false negative" test in
  // test/rules/stylistic/named_parameters_ordering_test.dart.
  final void Function({required String alpha, required String beta}) fn =
      exampleAlphaBetaFunction;
  fn(beta: 'b', alpha: 'a');
}

// named_parameters_ordering: metadata pins PLUS real detection coverage.
//
// History / why this file is shaped this way: the header of this file used to
// claim that firing behavior was "covered by the fixture's `expect_lint`
// markers, which the project's fixture-based integrity checks validate". That
// claim was FALSE for this rule — `named_parameters_ordering` appears in
// neither `test/scan/fixture_lint_integration_test.dart`'s
// `expectedFromFixtures` allow-list nor
// `test/integrity/plan_c_fixture_expect_lint_contract_test.dart`, so nothing
// in CI ever executed the rule. An off-by-one in the declared-index walk, or a
// silently dead enum / FunctionExpressionInvocation / super-initializer hook,
// would have shipped green. The tests below run the rule for real, through the
// resolved harness, so every hook and both the BAD and near-miss GOOD shapes
// are exercised.
//
// The harness requires RESOLVED analysis because the rule reads the callee's
// declared parameter order off the resolved `ExecutableElement`; a syntactic
// pass cannot know it. All fixtures here are pure Dart (no Flutter types), so
// they resolve fully inside the example package the harness writes into.
library;

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/named_parameters_ordering_rules.dart';

import '../../support/resolved_rule_harness.dart';

/// Shared declarations every case below is checked against. Kept in one string
/// so each test body contains only the call site under test, making a failure
/// point straight at the shape that regressed.
///
/// `Config` declares host, port, timeout; `exampleFunction` declares gamma,
/// alpha, beta — deliberately NON-alphabetical so a passing GOOD case proves
/// the rule follows DECLARATION order rather than accidentally agreeing with
/// `prefer_arguments_ordering`'s alphabetical convention.
const String _decls = '''
class Config {
  const Config({required this.host, required this.port, this.timeout});
  final String host;
  final int port;
  final int? timeout;
}

void exampleFunction({
  required String gamma,
  required String alpha,
  required String beta,
}) {}

void exampleMixedFunction(
  String label, {
  required String alpha,
  required String beta,
}) {}

void exampleAlphaBetaFunction({required String alpha, required String beta}) {}
''';

/// Wraps [body] in a function so statements are legal, and prepends the shared
/// declarations. `// ignore_for_file` keeps the analyzer's own unused-variable
/// noise out of the fixture; the harness only collects THIS rule's diagnostics
/// anyway, but a clean fixture avoids resolution surprises.
String _src(String body) =>
    '// ignore_for_file: unused_local_variable, prefer_const_constructors\n'
    '$_decls\n'
    'void caller() {\n$body\n}\n';

const String _ruleName = 'named_parameters_ordering';

void main() {
  group('NamedParametersOrderingRule - Rule Instantiation', () {
    test('NamedParametersOrderingRule', () {
      final rule = NamedParametersOrderingRule();
      expect(rule.code.lowerCaseName, _ruleName);
      expect(rule.code.problemMessage, contains('[named_parameters_ordering]'));
      // Project-wide rule: problem messages must exceed 200 chars total
      // (CLAUDE.md "Problem Message Requirements") so they carry enough
      // context to stand alone in an IDE tooltip without truncation.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('declares the prefer_arguments_ordering conflict', () {
      // `prefer_arguments_ordering` sorts alphabetically while this rule
      // follows declaration order, so for any non-alphabetical signature one
      // of the pair always fires. The conflict must stay machine-readable so
      // config tooling can warn before a user enables both.
      expect(
        NamedParametersOrderingRule().conflictingRules,
        contains('prefer_arguments_ordering'),
      );
    });
  });

  group('NamedParametersOrderingRule - fires (BAD cases)', () {
    test('constructor call with named args out of declaration order', () async {
      // host is declared before port; this call passes port first.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  const Config(port: 443, host: 'example.com');"),
      );
      expect(codes, contains(_ruleName));
    });

    test('constructor call with a trailing parameter moved first', () async {
      // timeout is declared LAST; leading with it violates the order even
      // though host/port that follow are themselves in order.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  const Config(timeout: 5, host: 'example.com', port: 443);"),
      );
      expect(codes, contains(_ruleName));
    });

    test('function call with named args out of declaration order', () async {
      // Declared gamma, alpha, beta — this call is alphabetical, which is
      // exactly what `prefer_arguments_ordering` wants and what this rule
      // must reject. Pins the two rules' opposition.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  exampleFunction(alpha: 'a', gamma: 'g', beta: 'b');"),
      );
      expect(codes, contains(_ruleName));
    });

    test('positional arg does not mask a reordered named pair', () async {
      // Edge case 4, bad variant: the leading positional `label` must not
      // enter the named index space, so beta-before-alpha still fires.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  exampleMixedFunction('x', beta: 'b', alpha: 'a');"),
      );
      expect(codes, contains(_ruleName));
    });

    test('enum constant declaration fires', () async {
      // EnumConstantDeclaration wraps its arguments differently from
      // InstanceCreationExpression and needs its own hook.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        '''
enum ExampleEnum {
  bad(beta: 'b', alpha: 'a');

  const ExampleEnum({required this.alpha, required this.beta});

  final String alpha;
  final String beta;
}
''',
      );
      expect(codes, contains(_ruleName));
    });

    test('super constructor invocation fires', () async {
      // Reached via addConstructorDeclaration + initializer walk, because
      // SaropaContext exposes no addSuperConstructorInvocation hook. This was
      // a documented false negative before that walk was added.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        '$_decls\n'
        'class ConfigSubclass extends Config {\n'
        '  ConfigSubclass(String host, int port)'
        ' : super(port: port, host: host);\n'
        '}\n',
      );
      expect(codes, contains(_ruleName));
    });

    test('redirecting constructor invocation fires', () async {
      // `: this(...)` is the other initializer form the same hook covers.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        '''
class RedirectTarget {
  RedirectTarget({required this.alpha, required this.beta});
  RedirectTarget.reordered(String a, String b) : this(beta: b, alpha: a);
  final String alpha;
  final String beta;
}
''',
      );
      expect(codes, contains(_ruleName));
    });
  });

  group('NamedParametersOrderingRule - stays silent (GOOD near-misses)', () {
    test('constructor call in declaration order', () async {
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  const Config(host: 'example.com', port: 443, timeout: 5);"),
      );
      expect(codes, isNot(contains(_ruleName)));
    });

    test('omitted trailing parameter leaves the rest in order', () async {
      // Only the RELATIVE order of the args actually present is checked, so a
      // gap in the declared index sequence must not be read as a violation.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  const Config(host: 'example.com', timeout: 5);"),
      );
      expect(codes, isNot(contains(_ruleName)));
    });

    test('single named argument has no order to violate', () async {
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  const Config(host: 'example.com');"),
      );
      expect(codes, isNot(contains(_ruleName)));
    });

    test('non-alphabetical declaration order is accepted', () async {
      // gamma, alpha, beta matches the declaration but is NOT alphabetical.
      // If this ever fires, the rule has drifted into sorting.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  exampleFunction(gamma: 'g', alpha: 'a', beta: 'b');"),
      );
      expect(codes, isNot(contains(_ruleName)));
    });

    test('positional arg interleaved with in-order named args', () async {
      // Edge case 4, good variant — the specific interleaving shape that an
      // off-by-one in the named-only index space would break: `label` occupies
      // argument slot 0 but must NOT consume declared index 0.
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        _src("  exampleMixedFunction('x', alpha: 'a', beta: 'b');"),
      );
      expect(codes, isNot(contains(_ruleName)));
    });

    // KNOWN FALSE NEGATIVE, pinned deliberately so it cannot be mistaken for
    // coverage. The rule registers `addFunctionExpressionInvocation` and the
    // visitor dispatch for that node type IS wired
    // (`compat_visitor.dart:visitFunctionExpressionInvocation`), but
    // `FunctionExpressionInvocation.element` is null when the callee is a
    // function-TYPED variable rather than a resolvable declaration, so
    // `_checkOrder`'s `is! ExecutableElement` guard bails before any check.
    // The declared named order for such a call site is only reachable through
    // `staticInvokeType` (a FunctionType), which the rule does not consult.
    // This test asserts the CURRENT behavior; flip it to `contains` if the
    // rule is ever taught to read the invoke type. Until then the
    // FunctionExpressionInvocation hook is effectively dead code.
    test(
      'FunctionExpressionInvocation is a documented false negative',
      () async {
        final codes = await reportedRuleCodes(
          NamedParametersOrderingRule(),
          _src(
            '  final void Function({required String alpha, required String'
            ' beta}) fn =\n'
            '      exampleAlphaBetaFunction;\n'
            "  fn(beta: 'b', alpha: 'a');",
          ),
        );
        expect(codes, isNot(contains(_ruleName)));
      },
    );

    test('super constructor invocation in declaration order', () async {
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        '$_decls\n'
        'class ConfigSubclassGood extends Config {\n'
        '  ConfigSubclassGood(String host, int port)'
        ' : super(host: host, port: port);\n'
        '}\n',
      );
      expect(codes, isNot(contains(_ruleName)));
    });

    test('enum constant in declaration order', () async {
      final codes = await reportedRuleCodes(
        NamedParametersOrderingRule(),
        '''
enum ExampleEnum {
  good(alpha: 'a', beta: 'b');

  const ExampleEnum({required this.alpha, required this.beta});

  final String alpha;
  final String beta;
}
''',
      );
      expect(codes, isNot(contains(_ruleName)));
    });
  });
}

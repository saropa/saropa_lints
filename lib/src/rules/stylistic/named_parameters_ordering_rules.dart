// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../saropa_lint_rule.dart';

/// Flags call sites where named arguments are passed in an order that
/// does not match the order the named parameters are declared in the
/// invoked constructor/function/method signature.
///
/// Since: v14.4.0 | Updated: v14.4.0 | Rule version: v1
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit —
/// call-site argument order has zero effect on the compiled program. This is
/// a pure readability convention: matching declaration order lets a reader
/// scan the call site against the signature without re-sorting mentally, and
/// keeps diffs between similar call sites minimal. Distinct from
/// `prefer_arguments_ordering`, which sorts named arguments alphabetically
/// (a different, unrelated convention this project also offers); this rule
/// instead mirrors the AUTHOR'S declared grouping (e.g. keeping related
/// `min`/`max` parameters adjacent), which alphabetical order would break.
///
/// Only the RELATIVE order of the named arguments actually present at the
/// call site is checked — omitted parameters, and any positional arguments,
/// do not affect the result. Redirecting/factory constructors are checked
/// against the immediate signature actually being invoked, not a redirect
/// target several hops away.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// // `host` is declared before `port`, but this call passes `port` first.
/// Config(port: 443, host: 'example.com');
/// ```
///
/// #### GOOD:
/// ```dart
/// Config(host: 'example.com', port: 443);
/// ```
class NamedParametersOrderingRule extends SaropaLintRule {
  NamedParametersOrderingRule() : super(code: _code);

  /// Pure style/readability preference; never a correctness or performance
  /// concern, so this stays at the lowest severity bucket.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention', 'stylistic'};

  @override
  RuleCost get cost => RuleCost.medium;

  /// Declaration order is only knowable from the resolved callee element —
  /// the AST alone cannot tell us how the invoked signature orders its
  /// named parameters, so this rule requires a resolved analysis context
  /// (`scan --resolve` / the IDE plugin path, which is always resolved).
  @override
  bool get usesTypeResolution => true;

  @override
  String get exampleBad =>
      "Config(port: 443, host: 'x');  // host is declared first";

  @override
  String get exampleGood =>
      "Config(host: 'x', port: 443);  // matches declaration order";

  /// Back-compat / discovery aliases matching the solid_lints rule this
  /// closes the competitive gap against.
  @override
  List<String> get configAliases => const <String>[
    'named_arguments_ordering',
  ];

  static const LintCode _code = LintCode(
    'named_parameters_ordering',
    '[named_parameters_ordering] Named arguments at this call site are not '
        'in the same relative order as the named parameters are declared in '
        'the invoked signature. Call-site order has no effect on the '
        'compiled program, but mismatched order forces a reader to re-sort '
        'the arguments mentally to match them against the declaration, and '
        'makes similar call sites diff-noisy against each other for no '
        'benefit. {v1}',
    correctionMessage:
        'Reorder the named arguments so their relative order matches the '
        'order the named parameters are declared in the invoked '
        'constructor/function/method signature.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // The immediate constructor being invoked — for a redirecting/factory
      // constructor this resolves to that constructor's OWN parameter list,
      // not the eventual redirect target, matching the proposal's edge case
      // 3 (evaluate against the signature actually being called).
      _checkOrder(node.constructorName.element, node.argumentList, reporter);
    });

    context.addMethodInvocation((MethodInvocation node) {
      _checkOrder(node.methodName.element, node.argumentList, reporter);
    });
  }

  /// Reports at most one violation per call site: the first named argument
  /// whose declared index is lower than an earlier argument's declared
  /// index. Bails out entirely (reports nothing) whenever the callee is
  /// unresolved or any call-site argument name cannot be matched back to a
  /// declared parameter — guessing in that situation risks a false positive
  /// on code we cannot actually verify, which the false-positive doctrine
  /// forbids.
  void _checkOrder(
    Element? calleeElement,
    ArgumentList argumentList,
    SaropaDiagnosticReporter reporter,
  ) {
    if (calleeElement is! ExecutableElement) return;

    // Map each declared named parameter to its position among ONLY the
    // named parameters (positional parameters do not participate in
    // named-argument ordering, so they are excluded from the index space).
    final Map<String, int> declaredIndexByName = <String, int>{};
    int nextIndex = 0;
    for (final FormalParameterElement param in calleeElement.formalParameters) {
      if (!param.isNamed) continue;
      final String? name = param.name;
      if (name == null) continue;
      declaredIndexByName[name] = nextIndex;
      nextIndex++;
    }
    // Fewer than 2 named parameters in the signature — no order to violate.
    if (declaredIndexByName.length < 2) return;

    // Named arguments actually present at the call site, in source order.
    final List<NamedExpression> namedArgs = <NamedExpression>[];
    for (final Expression arg in argumentList.arguments) {
      if (arg is NamedExpression) namedArgs.add(arg);
    }
    if (namedArgs.length < 2) return;

    int lastSeenDeclaredIndex = -1;
    for (final NamedExpression arg in namedArgs) {
      final String argName = arg.name.label.name;
      final int? declaredIndex = declaredIndexByName[argName];
      // An argument name with no matching declared parameter means the
      // signature could not be fully resolved for this call (e.g. a
      // synthetic/generated element) — bail rather than report against
      // incomplete information.
      if (declaredIndex == null) return;

      if (declaredIndex < lastSeenDeclaredIndex) {
        reporter.atNode(arg);
        return;
      }
      lastSeenDeclaredIndex = declaredIndex;
    }
  }
}

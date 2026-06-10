// ignore_for_file: depend_on_referenced_packages

/// go_router 6.0 migration rules (gated to the `go_router_6` rule pack).
///
/// go_router 6.0.0 changed the `redirect` callback signature to receive the
/// `BuildContext` as its first argument. These rules flag the pre-6.0 shape so
/// projects upgrading to go_router 6.x can find the call sites that no longer
/// compile. The whole pack is gated on `go_router >= 6.0.0`, so projects on
/// go_router 5.x — where the single-argument `redirect` is still correct — never
/// see it.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// Flags a pre-6.0 `redirect: (state) => ...` callback on go_router routes.
///
/// Since: v13.13.0 | Rule version: v1
///
/// go_router 6.0.0 changed the redirect callback from
/// `FutureOr<String?> Function(GoRouterState state)` to
/// `FutureOr<String?> Function(BuildContext context, GoRouterState state)`. A
/// single-parameter `redirect` closure passed to `GoRoute`, `GoRouter`, or
/// `ShellRoute` does not match the new typedef and will not compile against
/// go_router 6.x.
///
/// **BAD:**
/// ```dart
/// GoRoute(
///   path: '/home',
///   redirect: (state) => isLoggedIn ? null : '/login',   // pre-6.0 shape
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRoute(
///   path: '/home',
///   redirect: (context, state) => isLoggedIn ? null : '/login',
/// );
/// ```
class AvoidGoRouterLegacyRedirectRule extends SaropaLintRule {
  AvoidGoRouterLegacyRedirectRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  // Perf: only walk files that mention a redirect callback.
  @override
  Set<String>? get requiredPatterns => const <String>{'redirect'};

  // Constructors that accept the version-sensitive `redirect` callback.
  static const Set<String> _routeTypes = <String>{
    'GoRoute',
    'GoRouter',
    'ShellRoute',
    'StatefulShellRoute',
  };

  static const LintCode _code = LintCode(
    'avoid_go_router_legacy_redirect',
    '[avoid_go_router_legacy_redirect] go_router 6.0.0 changed the redirect callback to receive BuildContext as its first argument: Function(BuildContext context, GoRouterState state). A single-parameter redirect closure uses the pre-6.0 signature and will not compile against go_router 6.x. Add a leading context parameter to each inline redirect callback on GoRoute / GoRouter / ShellRoute. This rule only runs in the go_router_6 rule pack (go_router >= 6.0.0); projects on go_router 5.x keep the single-argument form. {v1}',
    correctionMessage:
        'Add a leading BuildContext parameter to the redirect callback: change redirect: (state) => ... to redirect: (context, state) => ....',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // A keyword-less `GoRoute(...)` is an InstanceCreationExpression in the
    // resolved AST (production / custom_lint) but a MethodInvocation in an
    // unresolved parse (the scan CLI). Register both so detection holds either
    // way; the shared logic in [_checkRedirect] is identical.
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      _checkRedirect(
        node,
        node.constructorName.type.name.lexeme,
        node.argumentList,
        reporter,
      );
    });
    context.addMethodInvocation((MethodInvocation node) {
      _checkRedirect(node, node.methodName.name, node.argumentList, reporter);
    });
  }

  void _checkRedirect(
    AstNode node,
    String typeName,
    ArgumentList argumentList,
    SaropaDiagnosticReporter reporter,
  ) {
    if (!_routeTypes.contains(typeName)) return;
    // Restrict to go_router files so a `redirect` argument on an unrelated
    // constructor/call is never mistaken for the router callback.
    if (!fileImportsPackage(node, PackageImports.goRouter)) return;

    for (final Expression arg in argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'redirect') continue;

      final Expression value = arg.expression;
      // Only inline closures expose their arity; tear-offs are left alone to
      // avoid false positives where the parameter list is not visible here.
      if (value is! FunctionExpression) continue;
      final FormalParameterList? params = value.parameters;
      if (params != null && params.parameters.length == 1) {
        reporter.atNode(params);
      }
    }
  }
}

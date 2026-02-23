// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// auto_route lint rules for Flutter applications.
///
/// These rules help identify common misuses of the auto_route package,
/// including string-based navigation and unintended stack clearing.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_auto_route_context_navigation
// =============================================================================

/// Warns when string-based `context.push`/`context.go` is used in an
/// auto_route project.
///
/// Since: v5.1.0 | Rule version: v1
///
/// auto_route provides typed route navigation (`context.router.push()`).
/// Using string-based `context.push('/path')` or `context.go('/path')`
/// bypasses the type-safe route system, breaks deep linking, and causes
/// navigation to target the wrong router in nested navigation.
///
/// **BAD:**
/// ```dart
/// onTap: () {
///   context.push('/products/123'); // String navigation in auto_route
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onTap: () {
///   context.router.push(ProductDetailRoute(id: 123));
/// }
/// ```
class AvoidAutoRouteContextNavigationRule extends SaropaLintRule {
  AvoidAutoRouteContextNavigationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'auto_route'};

  static const LintCode _code = LintCode(
    'avoid_auto_route_context_navigation',
    '[avoid_auto_route_context_navigation] String-based context.push() or '
        'context.go() is used in an auto_route project. auto_route provides '
        'typed route classes for navigation that are compile-time checked, '
        'support deep linking, and work correctly with nested routers. '
        'String-based navigation bypasses all of these benefits and can push '
        'onto the wrong router in nested navigation setups, causing confusing '
        'back-button behavior and incorrect URL updates on web. {v1}',
    correctionMessage:
        'Use typed route navigation: context.router.push(MyRoute()) or '
        'context.navigateTo(MyRoute()) instead of string-based navigation.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _navigationMethods = <String>{
    'push',
    'go',
    'pushNamed',
    'goNamed',
    'pushReplacementNamed',
    'pushReplacement',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_navigationMethods.contains(methodName)) return;

      // Check if target looks like a BuildContext (context.push)
      final Expression? target = node.target;
      if (target == null) return;
      final String targetSource = target.toSource();
      if (!targetSource.endsWith('context')) return;

      // Check if first argument is a string literal (string-based nav)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first is NamedExpression
          ? (args.first as NamedExpression).expression
          : args.first;

      final bool isStringNav =
          firstArg is SimpleStringLiteral ||
          firstArg is StringInterpolation ||
          firstArg is AdjacentStrings;

      if (!isStringNav) return;

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// avoid_auto_route_keep_history_misuse
// =============================================================================

/// Warns when `replaceAll` or `popUntilRoot` is used outside auth flows.
///
/// Since: v5.1.0 | Rule version: v1
///
/// `context.router.replaceAll([...])` clears the **entire** navigation stack.
/// `context.router.popUntilRoot()` pops back to the root route. These are
/// appropriate for authentication flows (login/logout/onboarding) but are a
/// common source of bugs when used for general navigation — the user loses
/// their back-button history.
///
/// **BAD:**
/// ```dart
/// onTap: () {
///   context.router.replaceAll([const HomeRoute(), const ProductsRoute()]);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _onLogout() {
///   context.router.replaceAll([const LoginRoute()]); // OK: auth flow
/// }
/// ```
class AvoidAutoRouteKeepHistoryMisuseRule extends SaropaLintRule {
  AvoidAutoRouteKeepHistoryMisuseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'auto_route'};

  static const LintCode _code = LintCode(
    'avoid_auto_route_keep_history_misuse',
    '[avoid_auto_route_keep_history_misuse] replaceAll() or popUntilRoot() '
        'clears the navigation stack outside an authentication flow. '
        'replaceAll destroys the user\'s entire navigation history so the '
        'back button no longer works as expected. popUntilRoot pops every '
        'intermediate route. These are appropriate for login, logout, and '
        'onboarding flows but are a common source of bugs when used for '
        'general navigation. The user loses their place and cannot navigate '
        'back to where they were. {v1}',
    correctionMessage:
        'Use context.router.push() for normal navigation. Reserve '
        'replaceAll() for authentication and onboarding flows only.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _destructiveMethods = <String>{
    'replaceAll',
    'popUntilRoot',
  };

  /// Auth-related function name fragments that indicate intentional use.
  /// Compared case-insensitively, so only lowercase entries are needed.
  static const Set<String> _authHeuristics = <String>{
    'login',
    'logout',
    'signout',
    'signin',
    'onboarding',
    'auth',
    'session',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_destructiveMethods.contains(methodName)) return;

      // Check if called on a router-like target
      final Expression? target = node.target;
      if (target == null) return;
      if (!_isRouterTarget(target)) return;

      // Suppress if inside an auth-related function
      if (_isInsideAuthFunction(node)) return;

      reporter.atNode(node, code);
    });
  }

  /// Checks if [target] is a router-like expression (e.g. `context.router`,
  /// `_router`, `AutoRouter.of(context)`).
  static bool _isRouterTarget(Expression target) {
    if (target is PrefixedIdentifier) {
      final String id = target.identifier.name;
      return id == 'router' || id.endsWith('Router');
    }
    if (target is PropertyAccess) {
      final String prop = target.propertyName.name;
      return prop == 'router' || prop.endsWith('Router');
    }
    if (target is SimpleIdentifier) {
      final String name = target.name;
      return name == 'router' || name.endsWith('Router');
    }
    return false;
  }

  /// Checks if [node] is inside a function whose name suggests an
  /// authentication flow.
  static bool _isInsideAuthFunction(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      String? functionName;
      if (current is MethodDeclaration) {
        functionName = current.name.lexeme;
      } else if (current is FunctionDeclaration) {
        functionName = current.name.lexeme;
      }
      if (functionName != null) {
        final String lower = functionName.toLowerCase();
        for (final String hint in _authHeuristics) {
          if (lower.contains(hint.toLowerCase())) return true;
        }
        return false;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when an `AutoRouteGuard` may not call `resolver.next()` on all paths.
///
/// Since: v5.1.0 | Rule version: v1
///
/// `AutoRouteGuard.onNavigation` **must** call `resolver.next(true/false)` on
/// every code path. A missing call causes the navigation to hang silently.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class AuthGuard extends AutoRouteGuard {
///   @override
///   void onNavigation(NavigationResolver resolver, StackRouter router) {
///     if (isLoggedIn) {
///       resolver.next(true);
///     }
///     // missing resolver.next(false) in else path!
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class AuthGuard extends AutoRouteGuard {
///   @override
///   void onNavigation(NavigationResolver resolver, StackRouter router) {
///     if (isLoggedIn) {
///       resolver.next(true);
///     } else {
///       resolver.next(false);
///     }
///   }
/// }
/// ```
class RequireAutoRouteGuardResumeRule extends SaropaLintRule {
  RequireAutoRouteGuardResumeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'auto_route'};

  static const LintCode _code = LintCode(
    'require_auto_route_guard_resume',
    '[require_auto_route_guard_resume] An AutoRouteGuard.onNavigation '
        'override must call resolver.next() on every code path. Missing '
        'calls cause navigation to hang silently with no error message, '
        'leaving the user stuck on the current page. Ensure both the if '
        'and else branches call resolver.next(true) or resolver.next(false) '
        'respectively. {v1}',
    correctionMessage:
        'Add resolver.next(false) to the missing branch (typically the '
        'else clause).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if implements AutoRouteGuard
      final ImplementsClause? impl = node.implementsClause;
      if (impl == null) return;
      final bool isGuard = impl.interfaces.any(
        (NamedType t) => t.name2.lexeme == 'AutoRouteGuard',
      );
      if (!isGuard) return;

      // Find onNavigation method
      for (final ClassMember member in node.members) {
        if (member is! MethodDeclaration) continue;
        if (member.name.lexeme != 'onNavigation') continue;

        final String bodySource = member.body.toSource();
        final int nextCalls = RegExp(
          r'resolver\.next\b',
        ).allMatches(bodySource).length;

        // Heuristic: an if-else with resolver.next needs at least 2 calls
        if (RegExp(r'\bif\b').hasMatch(bodySource) && nextCalls < 2) {
          reporter.atToken(member.name);
        }
      }
    });
  }
}

/// Warns when `context.router.push()` is used in an auto_route project.
///
/// Since: v5.1.0 | Rule version: v1
///
/// In auto_route, `push()` doesn't respect the route hierarchy — it pushes
/// a flat route without parent wrappers. Use `navigate()` instead so the
/// full route tree (including parent shell routes) is preserved.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// context.router.push(const ProfileRoute());
/// ```
///
/// #### GOOD:
/// ```dart
/// context.router.navigate(const ProfileRoute());
/// ```
class RequireAutoRouteFullHierarchyRule extends SaropaLintRule {
  RequireAutoRouteFullHierarchyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'auto_route'};

  static const LintCode _code = LintCode(
    'require_auto_route_full_hierarchy',
    '[require_auto_route_full_hierarchy] Using push() in auto_route bypasses '
        'the route hierarchy, so parent shell routes and wrapper widgets are '
        'not applied. This causes missing bottom navigation bars, app bars, '
        'or layout scaffolds. Use navigate() instead to push the full route '
        'tree including all parent wrappers. {v1}',
    correctionMessage:
        'Replace push() with navigate() to preserve the route hierarchy.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'push') return;

      // Target must be a router
      final Expression? target = node.realTarget;
      if (target == null) return;
      final String targetSource = target.toSource();
      if (!targetSource.endsWith('router')) return;

      // Argument should be a Route object (not a string)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;
      if (args.first is SimpleStringLiteral) return; // string-based nav

      reporter.atNode(node.methodName);
    });
  }
}

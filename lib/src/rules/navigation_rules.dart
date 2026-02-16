// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, unused_element

/// Navigation lint rules for Flutter applications.
///
/// These rules help identify common navigation issues including unnamed
/// routes, missing error handlers, and context usage after navigation.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../import_utils.dart';
import '../saropa_lint_rule.dart';

// =============================================================================
// Flutter Navigation Rules
// =============================================================================

/// Warns when MaterialApp/CupertinoApp lacks onUnknownRoute.
///
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: add_unknown_route, fallback_route, route_not_found_handler
///
/// Without onUnknownRoute, navigating to an undefined route crashes the app.
/// Always provide a fallback for unknown routes.
///
/// **BAD:**
/// ```dart
/// MaterialApp(
///   routes: {
///     '/home': (_) => HomePage(),
///   },
///   // Missing onUnknownRoute - app crashes on unknown routes!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialApp(
///   routes: {
///     '/home': (_) => HomePage(),
///   },
///   onUnknownRoute: (settings) => MaterialPageRoute(
///     builder: (_) => NotFoundPage(),
///   ),
/// )
/// ```
class RequireUnknownRouteHandlerRule extends SaropaLintRule {
  const RequireUnknownRouteHandlerRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_unknown_route_handler',
    problemMessage:
        '[require_unknown_route_handler] MaterialApp or CupertinoApp defines routes or onGenerateRoute but does not provide an onUnknownRoute handler. When a user navigates to an undefined route path via deep link, push notification, or programmatic navigation, the app throws an unhandled exception and crashes instead of showing a helpful error screen. {v4}',
    correctionMessage:
        'Add an onUnknownRoute callback to MaterialApp that returns a route to a user-friendly 404 error page when navigation targets an undefined route path.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'MaterialApp' &&
          constructorName != 'CupertinoApp') {
        return;
      }

      bool hasRoutes = false;
      bool hasOnUnknownRoute = false;
      bool hasRouter = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'routes' || name == 'onGenerateRoute') {
            hasRoutes = true;
          }
          if (name == 'onUnknownRoute') {
            hasOnUnknownRoute = true;
          }
          // If using router, they handle unknown routes differently
          if (name == 'routerConfig' || name == 'routerDelegate') {
            hasRouter = true;
          }
        }
      }

      if (hasRoutes && !hasOnUnknownRoute && !hasRouter) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when BuildContext is used after an await in navigation.
///
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: avoid_dialog_context_after_async, context_after_await, mounted_check
///
/// After awaiting a navigation operation, the widget may be disposed.
/// Using the BuildContext after this can cause errors or unexpected behavior.
///
/// **BAD:**
/// ```dart
/// Future<void> navigate() async {
///   final result = await Navigator.pushNamed(context, '/details');
///   ScaffoldMessenger.of(context).showSnackBar(...); // Context may be invalid!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> navigate() async {
///   final result = await Navigator.pushNamed(context, '/details');
///   if (!mounted) return;
///   ScaffoldMessenger.of(context).showSnackBar(...);
/// }
/// ```
class AvoidContextAfterNavigationRule extends SaropaLintRule {
  const AvoidContextAfterNavigationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_context_after_navigation',
    problemMessage:
        '[avoid_context_after_navigation] BuildContext accessed after an awaited navigation call without a mounted check. The widget that owns this context is likely disposed by the time the await completes, and calling ScaffoldMessenger.of(), Navigator.of(), or Theme.of() on a disposed context throws a FlutterError that crashes the app or produces silent failures in release mode. {v3}',
    correctionMessage:
        'Insert "if (!mounted) return;" immediately after the awaited navigation call and before any subsequent BuildContext usage to guard against accessing a disposed widget tree.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.body.isAsynchronous) return;

      // Check if in a State class
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      if (superclass.name.lexeme != 'State') return;

      node.body.visitChildren(_NavigationContextVisitor(reporter, code));
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddMountedCheckFix()];
}

class _NavigationContextVisitor extends RecursiveAstVisitor<void> {
  _NavigationContextVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  bool _awaitedNavigation = false;
  bool _hasMountedCheck = false;

  static const Set<String> _navigationMethods = <String>{
    'push',
    'pushNamed',
    'pushReplacement',
    'pushReplacementNamed',
    'pushAndRemoveUntil',
    'pop',
    'popAndPushNamed',
    'maybePop',
    'popUntil',
  };

  @override
  void visitAwaitExpression(AwaitExpression node) {
    // Check if this await is on a navigation method
    final Expression expression = node.expression;
    if (expression is MethodInvocation) {
      if (_navigationMethods.contains(expression.methodName.name)) {
        _awaitedNavigation = true;
        _hasMountedCheck = false;
      }
    }
    super.visitAwaitExpression(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    final String condition = node.expression.toSource();
    if (condition.contains('mounted')) {
      _hasMountedCheck = true;
    }
    super.visitIfStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for context usage after awaited navigation
    if (_awaitedNavigation && !_hasMountedCheck) {
      // Check if target is a context-dependent call (e.g., Navigator.of(context))
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource();
        if (targetSource == 'context' ||
            targetSource == 'Navigator.of(context)' ||
            targetSource == 'ScaffoldMessenger.of(context)' ||
            targetSource == 'Theme.of(context)') {
          reporter.atNode(node, code);
        }
      }
      // Check arguments for direct context usage
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is SimpleIdentifier && arg.name == 'context') {
          reporter.atNode(node, code);
          break;
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _AddMountedCheckFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add mounted check before this',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          'if (!mounted) return;\n    ',
        );
      });
    });
  }
}

/// Warns when different page route transition types are mixed in the same app.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: consistent_transitions, mixed_page_routes, page_transition_theme
///
/// Inconsistent transitions (some pages slide, others fade, others pop)
/// feel unprofessional. Use consistent page transitions throughout.
///
/// **BAD:**
/// ```dart
/// // In different parts of the app:
/// Navigator.push(context, MaterialPageRoute(builder: (_) => PageA()));
/// Navigator.push(context, CupertinoPageRoute(builder: (_) => PageB()));
/// Navigator.push(context, FadeTransitionRoute(builder: (_) => PageC()));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use consistent transitions via ThemeData or custom PageTransitionsBuilder
/// theme: ThemeData(
///   pageTransitionsTheme: PageTransitionsTheme(
///     builders: {
///       TargetPlatform.android: CupertinoPageTransitionsBuilder(),
///       TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
///     },
///   ),
/// )
/// ```
class RequireRouteTransitionConsistencyRule extends SaropaLintRule {
  const RequireRouteTransitionConsistencyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_route_transition_consistency',
    problemMessage:
        '[require_route_transition_consistency] Multiple route transition types (MaterialPageRoute, CupertinoPageRoute, PageRouteBuilder) are mixed in the same file. Mixing slide, fade, and zoom transitions within a single app produces a jarring, unprofessional navigation experience that disorients users and undermines perceived app quality. {v4}',
    correctionMessage:
        'Define a unified transition strategy in ThemeData.pageTransitionsTheme and use a single route type throughout the app to ensure all page transitions are visually consistent.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _routeTypes = <String>{
    'MaterialPageRoute',
    'CupertinoPageRoute',
    'PageRouteBuilder',
    'FadeRoute',
    'SlideRoute',
    'FadeTransitionRoute',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track route types found in this file
    final Set<String> foundRouteTypes = <String>{};
    final List<AstNode> routeNodes = <AstNode>[];

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != null && _routeTypes.contains(typeName)) {
        foundRouteTypes.add(typeName);
        routeNodes.add(node);
      }
    });

    // After visiting all nodes, check for inconsistency
    context.addPostRunCallback(() {
      // If multiple different route types are used, flag them
      if (foundRouteTypes.length > 1) {
        // Report on all route usages except the first type found
        final String firstType = foundRouteTypes.first;
        for (final AstNode node in routeNodes) {
          if (node is InstanceCreationExpression) {
            final String? typeName = node.constructorName.type.element?.name;
            if (typeName != firstType) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Navigator.push is used without named routes.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// Named routes provide better maintainability, deep linking support,
/// and enable route guards. Inline routes are harder to track.
///
/// **BAD:**
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => DetailsPage()),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Navigator.pushNamed(context, '/details');
///
/// // Or use go_router
/// context.go('/details');
/// ```
class AvoidNavigatorPushUnnamedRule extends SaropaLintRule {
  const AvoidNavigatorPushUnnamedRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_navigator_push_unnamed',
    problemMessage:
        '[avoid_navigator_push_unnamed] Navigator.push used with an inline route constructor instead of a named route. Inline routes prevent deep linking, break URL-based navigation, and make route management unmaintainable. Users cannot share or bookmark specific screens, and analytics tools cannot track page views accurately. {v3}',
    correctionMessage:
        'Define named routes in MaterialApp.routes or use a router package such as go_router. This ensures navigation is maintainable, testable, and less error-prone as your app scales. Update all push calls to use named routes for clarity and reliability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Navigator.push (not pushNamed)
      if (methodName != 'push') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource != 'Navigator' &&
          !targetSource.startsWith('Navigator.')) {
        return;
      }

      // Check if second argument is a MaterialPageRoute/CupertinoPageRoute
      // (which indicates inline route definition)
      if (node.argumentList.arguments.length >= 2) {
        final Expression secondArg = node.argumentList.arguments[1];
        if (secondArg is InstanceCreationExpression) {
          final String? typeName = secondArg.constructorName.type.element?.name;
          if (typeName == 'MaterialPageRoute' ||
              typeName == 'CupertinoPageRoute' ||
              typeName == 'PageRouteBuilder') {
            reporter.atNode(node.methodName, code);
          }
        }
      }
    });
  }
}

/// Warns when protected routes lack authentication checks.
///
/// Since: v1.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// Routes that require authentication should redirect unauthenticated
/// users. Missing auth checks can expose sensitive data.
///
/// **BAD:**
/// ```dart
/// GoRoute(
///   path: '/profile',
///   builder: (_, __) => ProfilePage(), // No auth check!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRoute(
///   path: '/profile',
///   redirect: (context, state) {
///     if (!authService.isLoggedIn) return '/login';
///     return null;
///   },
///   builder: (_, __) => ProfilePage(),
/// )
/// ```
class RequireRouteGuardsRule extends SaropaLintRule {
  const RequireRouteGuardsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_route_guards',
    problemMessage:
        '[require_route_guards] Protected route path (profile, settings, admin, payment) lacks an authentication guard. Without a redirect callback, unauthorized users can access sensitive pages directly via deep link or URL manipulation, exposing personal data, financial information, or admin controls to unauthenticated sessions. {v3}',
    correctionMessage:
        'Add a redirect callback or middleware to check authentication before allowing access to this route. Ensure that only authorized users can reach protected pages, and redirect unauthenticated users to a login or error page. This helps prevent unauthorized access and protects user data.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _protectedRoutePatterns = <String>{
    'profile',
    'settings',
    'account',
    'dashboard',
    'admin',
    'private',
    'protected',
    'checkout',
    'payment',
    'order',
    'wallet',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'GoRoute' && typeName != 'Route') return;

      String? routePath;
      bool hasRedirect = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'path' && arg.expression is SimpleStringLiteral) {
            routePath = (arg.expression as SimpleStringLiteral).value;
          }
          if (name == 'redirect') {
            hasRedirect = true;
          }
        }
      }

      if (routePath == null || hasRedirect) return;

      // Check if route path suggests protected content
      final String pathLower = routePath.toLowerCase();
      for (final String pattern in _protectedRoutePatterns) {
        if (pathLower.contains(pattern)) {
          reporter.atNode(node.constructorName, code);
          return;
        }
      }
    });
  }
}

/// Warns when route redirects could create infinite loops.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Circular redirects (A -> B -> A) cause the app to hang or crash.
/// Always ensure redirect chains terminate.
///
/// **BAD:**
/// ```dart
/// // login redirects to home, home redirects to login for unauthenticated
/// GoRoute(
///   path: '/login',
///   redirect: (_, __) => '/home', // Always redirects!
/// ),
/// GoRoute(
///   path: '/home',
///   redirect: (_, __) => isLoggedIn ? null : '/login',
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRoute(
///   path: '/login',
///   redirect: (_, __) => isLoggedIn ? '/home' : null,
/// ),
/// GoRoute(
///   path: '/home',
///   redirect: (_, __) => isLoggedIn ? null : '/login',
/// )
/// ```
class AvoidCircularRedirectsRule extends SaropaLintRule {
  const AvoidCircularRedirectsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_circular_redirects',
    problemMessage:
        '[avoid_circular_redirects] GoRoute redirect callback always returns a path and never returns null, creating an unconditional redirect that forms an infinite loop. The router exhausts the redirect limit and throws an exception, crashing the app or permanently locking users out of all navigation when the redirect chain has no termination condition. {v2}',
    correctionMessage:
        'Update your redirect callback to always include a condition that returns null in some cases, breaking the redirect chain. This prevents infinite navigation loops and ensures users can access the intended pages without being stuck.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'GoRoute') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'redirect') {
          final Expression redirectExpr = arg.expression;

          // Check if redirect always returns a value (no conditional null)
          if (redirectExpr is FunctionExpression) {
            final FunctionBody body = redirectExpr.body;
            final String bodySource = body.toSource();

            // Check for unconditional redirect
            if (body is ExpressionFunctionBody) {
              // => '/path' always redirects
              if (!bodySource.contains('null') &&
                  !bodySource.contains('?') &&
                  !bodySource.contains('if')) {
                reporter.atNode(arg.expression, code);
              }
            } else if (body is BlockFunctionBody) {
              // Must have a return null somewhere
              if (!bodySource.contains('return null') &&
                  !bodySource.contains('return;')) {
                reporter.atNode(arg.expression, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when Navigator.pop result is not handled.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// When a page returns a result via pop, the caller should handle
/// the possibility of null (user pressed back button).
///
/// **BAD:**
/// ```dart
/// final result = await Navigator.push(context, ...);
/// saveData(result); // May be null if user pressed back!
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await Navigator.push<String>(context, ...);
/// if (result != null) {
///   saveData(result);
/// }
/// ```
class AvoidPopWithoutResultRule extends SaropaLintRule {
  const AvoidPopWithoutResultRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_pop_without_result',
    problemMessage:
        '[avoid_pop_without_result] Navigator.push awaits a result but does not handle the null case when the user dismisses the route by pressing the back button or using a system gesture. Accessing properties on a null result throws a runtime exception that crashes the app. This creates a fragile navigation flow that fails under normal user interaction patterns. {v2}',
    correctionMessage:
        'Check if the navigation result is null before accessing its properties, and provide a default value or early return to handle route dismissal without a result.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAwaitExpression((AwaitExpression node) {
      final Expression expression = node.expression;
      if (expression is! MethodInvocation) return;

      final String methodName = expression.methodName.name;
      if (methodName != 'push' &&
          methodName != 'pushNamed' &&
          methodName != 'pushReplacement' &&
          methodName != 'pushReplacementNamed') {
        return;
      }

      // Check if target is Navigator
      final Expression? target = expression.target;
      if (target == null) return;
      final String navTarget = target.toSource();
      if (navTarget != 'Navigator' && !navTarget.startsWith('Navigator.')) {
        return;
      }

      // Check if result is used without null check
      final AstNode? parent = node.parent;
      if (parent is VariableDeclaration) {
        // Check if the variable is used without null check
        final String varName = parent.name.lexeme;

        // Look for usage of this variable
        final AstNode? grandparent = parent.parent?.parent?.parent;
        if (grandparent != null) {
          final String remainingCode = grandparent.toSource();
          // Very simplified check - if variable is used and no null check
          if (remainingCode.contains(varName) &&
              !remainingCode.contains('$varName != null') &&
              !remainingCode.contains('$varName == null') &&
              !remainingCode.contains('$varName!') &&
              !remainingCode.contains('$varName?')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when persistent UI elements aren't using ShellRoute.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Bottom navigation bars, sidebars, and other persistent UI should
/// use ShellRoute to avoid rebuilding on navigation.
///
/// **BAD:**
/// ```dart
/// // Bottom nav rebuilds on every navigation
/// GoRouter(
///   routes: [
///     GoRoute(path: '/home', builder: (_, __) =>
///       Scaffold(
///         body: HomePage(),
///         bottomNavigationBar: BottomNav(), // Rebuilds!
///       ),
///     ),
///     GoRoute(path: '/profile', builder: (_, __) =>
///       Scaffold(
///         body: ProfilePage(),
///         bottomNavigationBar: BottomNav(), // Duplicate!
///       ),
///     ),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRouter(
///   routes: [
///     ShellRoute(
///       builder: (_, __, child) => Scaffold(
///         body: child,
///         bottomNavigationBar: BottomNav(),
///       ),
///       routes: [
///         GoRoute(path: '/home', builder: (_, __) => HomePage()),
///         GoRoute(path: '/profile', builder: (_, __) => ProfilePage()),
///       ],
///     ),
///   ],
/// )
/// ```
class PreferShellRouteForPersistentUiRule extends SaropaLintRule {
  const PreferShellRouteForPersistentUiRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_shell_route_for_persistent_ui',
    problemMessage:
        '[prefer_shell_route_for_persistent_ui] Multiple GoRoute builders duplicate the same bottomNavigationBar, drawer, or NavigationRail instead of sharing a single wrapper. Each route rebuilds the persistent UI independently, causing duplicated code, inconsistent selection state across tabs, visual flicker during navigation, and increased memory usage from redundant widget trees. {v2}',
    correctionMessage:
        'Wrap related routes in a ShellRoute to share persistent UI elements like bottomNavigationBar or drawer. This ensures consistent UI state, reduces code duplication, and improves navigation reliability across your app.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track routes with bottomNavigationBar/drawer
    final List<InstanceCreationExpression> routesWithPersistentUi =
        <InstanceCreationExpression>[];

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'GoRoute') return;

      // Check if builder has Scaffold with bottomNavigationBar
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();
          if (builderSource.contains('bottomNavigationBar') ||
              builderSource.contains('drawer') ||
              builderSource.contains('NavigationRail')) {
            routesWithPersistentUi.add(node);
          }
        }
      }
    });

    context.addPostRunCallback(() {
      // If multiple routes have persistent UI, suggest ShellRoute
      if (routesWithPersistentUi.length > 1) {
        for (final InstanceCreationExpression node in routesWithPersistentUi) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Warns when deep link handler lacks fallback for invalid/missing content.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v9
///
/// Deep links may reference content that doesn't exist or has been deleted.
/// Always handle the case where the linked content is unavailable.
///
/// **Quick fix available:** Wraps the handler body with try/catch for
/// fallback handling.
///
/// **Skipped patterns** (not deep link handlers):
/// - Widget builders: methods returning Widget types (including
///   `Future<Widget>`, `PreferredSizeWidget`, etc.)
/// - Utility getters: `is*`, `has*`, `check*`, `valid*` prefixes
/// - State methods: `reset*`, `clear*`, `set*` prefixes
/// - Simple field returns: `=> _uri`, `=> prefix.uri`
/// - Lazy-loading: `=> _uri ??= parseUri(url)`
/// - URI conversions: `=> url.toUri()`, `=> url?.toUriSafe()`
/// - Property access: `=> url?.uri`
/// - Trivial blocks: `{ return _uri; }`, `{ _uri = value; }`
/// - No deep link signals: body lacks `Uri`, `pathSegments`,
///   `queryParameters`, `Navigator`, `GoRouter`, or navigation calls
///
/// **BAD:**
/// ```dart
/// void handleDeepLink(Uri uri) {
///   final productId = uri.pathSegments[1];
///   Navigator.push(context, ProductPage(id: productId));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void handleDeepLink(Uri uri) async {
///   final productId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
///   if (productId == null) {
///     Navigator.pushReplacement(context, NotFoundPage());
///     return;
///   }
///   final product = await productService.getProduct(productId);
///   if (product == null) {
///     Navigator.pushReplacement(context, NotFoundPage());
///     return;
///   }
///   Navigator.push(context, ProductPage(product: product));
/// }
/// ```
class RequireDeepLinkFallbackRule extends SaropaLintRule {
  const RequireDeepLinkFallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_deep_link_fallback',
    problemMessage:
        '[require_deep_link_fallback] Deep link handler navigates to content without verifying the target exists or is accessible. When a deep link references deleted, restricted, or invalid content, the app either crashes with a null reference error or displays a blank screen. Users tapping expired links in emails, notifications, or shared messages encounter a broken experience. {v9}',
    correctionMessage:
        'Add a fallback route or error screen that displays a user-friendly message when deep-linked content is missing, deleted, or inaccessible, with an option to navigate home.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme.toLowerCase();

      // Check for deep link handling methods
      if (!methodName.contains('deeplink') &&
          !methodName.contains('link') &&
          !methodName.contains('uri') &&
          !methodName.contains('route')) {
        return;
      }

      // Skip utility methods that return String, Uri, or Widget types
      // These are parsers/converters/builders, not deep link handlers
      // e.g., String? accountIdFromUri(Uri uri) - extracts data from URI
      // e.g., Uri? get storedUri - simple getter
      // e.g., Widget _buildShareLinkButton() - UI builder
      // e.g., Future<Widget> buildRoutePreview() - async widget builder
      // e.g., PreferredSizeWidget buildLinkAppBar() - widget subtype
      final String? returnTypeStr = node.returnType?.toSource();
      if (returnTypeStr != null) {
        final String trimmed = returnTypeStr.replaceAll('?', '').trim();
        if (trimmed == 'String' ||
            trimmed == 'Uri' ||
            trimmed.contains('Widget')) {
          return;
        }
      }

      // Skip utility getters and simple boolean checks
      // These are helpers, not actual deep link handlers
      // Use endsWith instead of contains to be more precise:
      // - isUriEmpty ✓ (utility)
      // - handleEmptyDeepLink ✗ (might be actual handler)
      if (node.isGetter &&
          (methodName.startsWith('is') ||
              methodName.startsWith('has') ||
              methodName.startsWith('check') ||
              methodName.startsWith('valid') ||
              methodName.endsWith('empty') ||
              methodName.endsWith('null') ||
              methodName.endsWith('nullable'))) {
        return;
      }

      // Skip utility methods that manage state rather than handle deep links
      // e.g., resetInitialUri(), clearUri(), setRouteUri()
      if (methodName.startsWith('reset') ||
          methodName.startsWith('clear') ||
          methodName.startsWith('set')) {
        return;
      }

      final FunctionBody? body = node.body;
      if (body == null) return;

      final String bodySource = body.toSource();

      // Skip simple expression body methods that just return a field or convert
      // e.g., Uri? get initialUri => _initialUri;
      // e.g., Uri? getStoredUri() => _uri;
      // e.g., Uri? get uri => _uri ??= parseUri(url);
      // e.g., Uri? get uri => url.toUri();
      if (body is ExpressionFunctionBody) {
        final Expression expr = body.expression;
        // Simple field access or identifier (e.g., => _field or => field)
        if (expr is SimpleIdentifier || expr is PrefixedIdentifier) {
          return;
        }

        // Lazy-loading pattern: _field ??= value
        if (expr is AssignmentExpression &&
            expr.operator.type == TokenType.QUESTION_QUESTION_EQ) {
          return;
        }

        // Simple method invocation on a field: field.toUri(), url?.toUri()
        // These are URI conversion utilities, not deep link handlers
        if (expr is MethodInvocation) {
          final Expression? target = expr.target;
          if (target == null ||
              target is SimpleIdentifier ||
              target is PrefixedIdentifier ||
              target is ThisExpression) {
            return;
          }
        }

        // Null-aware property access: url?.uri
        if (expr is PropertyAccess) {
          final Expression? target = expr.target;
          if (target == null ||
              target is SimpleIdentifier ||
              target is PrefixedIdentifier ||
              target is ThisExpression) {
            return;
          }
        }

        // Ternary with null fallback: condition ? value : null
        // e.g., String? get postUriAt => postId.isNotEmpty ? 'at://$postId' : null;
        if (expr is ConditionalExpression) {
          if (expr.elseExpression is NullLiteral ||
              expr.thenExpression is NullLiteral) {
            return; // Has null fallback
          }
        }
      }

      // Skip trivial method bodies (single statement that is assignment or return)
      // e.g., void resetUri() { _uri = null; }
      // e.g., Uri? getUri() { return _uri; }
      if (body is BlockFunctionBody) {
        final Block block = body.block;
        if (block.statements.length == 1) {
          final Statement stmt = block.statements.first;
          // Single assignment: void setUri(Uri? u) { _uri = u; }
          if (stmt is ExpressionStatement &&
              stmt.expression is AssignmentExpression) {
            return;
          }
          // Single return of simple value: Uri? getUri() { return _uri; }
          if (stmt is ReturnStatement) {
            final Expression? returnExpr = stmt.expression;
            if (returnExpr == null ||
                returnExpr is SimpleIdentifier ||
                returnExpr is PrefixedIdentifier ||
                returnExpr is NullLiteral) {
              return;
            }
          }
        }
      }

      // Skip methods whose body has no deep link signals
      // If the body doesn't parse URIs or navigate, it's not a handler
      // regardless of method name
      final bool hasDeepLinkSignal = bodySource.contains('Uri') ||
          bodySource.contains('pathSegments') ||
          bodySource.contains('queryParameters') ||
          bodySource.contains('Navigator') ||
          bodySource.contains('GoRouter') ||
          bodySource.contains('.go(') ||
          bodySource.contains('.goNamed(') ||
          bodySource.contains('.push(') ||
          bodySource.contains('.pushNamed(') ||
          bodySource.contains('.pushReplacement') ||
          bodySource.contains('getInitialLink') ||
          bodySource.contains('getInitialUri');

      if (!hasDeepLinkSignal) return;

      // Check for fallback patterns
      final bool hasFallback = bodySource.contains('NotFound') ||
          bodySource.contains('404') ||
          bodySource.contains('error') ||
          bodySource.contains('null)') ||
          bodySource.contains('return null') ||
          bodySource.contains('== null') ||
          bodySource.contains('isEmpty') ||
          bodySource.contains('try') ||
          bodySource.contains('catch');

      if (!hasFallback) {
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDeepLinkFallbackFix()];
}

/// Quick fix that wraps the deep link handler body with a try/catch pattern.
class _AddDeepLinkFallbackFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.name.sourceRange)) return;

      final FunctionBody? body = node.body;
      if (body == null) return;

      // Only fix block function bodies, not expression bodies
      if (body is! BlockFunctionBody) return;

      final Block block = body.block;
      final String indent = '    '; // Standard 4-space indent

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap with try/catch for fallback handling',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert try { after opening brace
        builder.addSimpleInsertion(
          block.leftBracket.end,
          '\n${indent}try {',
        );

        // Insert catch block before closing brace
        builder.addSimpleInsertion(
          block.rightBracket.offset,
          '} catch (e) {\n'
          '$indent  // TODO: Handle error - show NotFound page or error message\n'
          '$indent  rethrow;\n'
          '$indent}\n$indent',
        );
      });
    });
  }
}

// cspell:ignore myapp
/// Warns when deep link contains sensitive parameters like password or token.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Deep links are logged and may be visible in browser history or analytics.
/// Never pass sensitive data via deep link parameters.
///
/// **BAD:**
/// ```dart
/// // myapp://reset-password?token=abc123&password=secret
/// final password = uri.queryParameters['password'];
/// ```
///
/// **GOOD:**
/// ```dart
/// // myapp://reset-password?token=abc123
/// // Token is one-time use, fetches new password from server
/// final token = uri.queryParameters['token'];
/// ```
class AvoidDeepLinkSensitiveParamsRule extends SaropaLintRule {
  const AvoidDeepLinkSensitiveParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_deep_link_sensitive_params',
    problemMessage:
        '[avoid_deep_link_sensitive_params] Deep link query parameter contains sensitive data (password, token, secret, API key, or credential), creating a security breach. Deep link URLs are recorded in system logs, browser history, HTTP referrer headers, and analytics platforms, permanently exposing credentials to attackers who gain access to those logs or the device history. {v4}',
    correctionMessage:
        'Remove sensitive parameters from deep link URLs and exchange them server-side using a one-time token or secure session instead of transmitting credentials in the URL.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _sensitiveParams = <String>{
    'password',
    'passwd',
    'secret',
    'api_key',
    'apikey',
    'access_token',
    'refresh_token',
    'auth_token',
    'bearer',
    'credential',
    'credit_card',
    'ssn',
    'pin',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      // Check for uri.queryParameters['password']
      final Expression? target = node.target;
      if (target == null) return;
      final String targetSource = target.toSource();

      if (!targetSource.contains('queryParameters') &&
          !targetSource.contains('pathSegments')) {
        return;
      }

      final Expression index = node.index;
      if (index is SimpleStringLiteral) {
        final String paramName = index.value.toLowerCase();
        if (_sensitiveParams.contains(paramName)) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when route parameters are used as strings without type conversion.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Route parameters are always strings. Using them directly without parsing
/// can cause type mismatches and bugs. Parse to correct type.
///
/// **BAD:**
/// ```dart
/// GoRoute(
///   path: '/user/:id',
///   builder: (context, state) {
///     final id = state.pathParameters['id']!;  // String!
///     return UserPage(userId: id);  // Expects int?
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRoute(
///   path: '/user/:id',
///   builder: (context, state) {
///     final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
///     return UserPage(userId: id);
///   },
/// )
/// ```
class PreferTypedRouteParamsRule extends SaropaLintRule {
  const PreferTypedRouteParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_typed_route_params',
    problemMessage:
        '[prefer_typed_route_params] Route parameter from pathParameters or queryParameters is passed directly without type conversion. All route parameters are strings at runtime, and passing them where an int, double, or bool is expected causes type mismatch errors or silent data corruption. {v3}',
    correctionMessage:
        'Parse route parameters with int.tryParse(), double.tryParse(), or bool.parse() and provide a fallback default value to handle malformed or missing input safely.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      final Expression? target = node.target;
      if (target == null) return;
      final String targetSource = target.toSource();

      if (!targetSource.contains('pathParameters') &&
          !targetSource.contains('queryParameters')) {
        return;
      }

      // Check if result is immediately used without parsing
      final AstNode? parent = node.parent;

      // OK if wrapped in parse
      if (parent is ArgumentList) {
        final AstNode? grandparent = parent.parent;
        if (grandparent is MethodInvocation) {
          final String methodName = grandparent.methodName.name;
          if (methodName.contains('parse') || methodName.contains('Parse')) {
            return;
          }
        }
      }

      // OK if assigned to variable (might be parsed later)
      if (parent is VariableDeclaration) return;
      if (parent is AssignmentExpression) return;

      // OK if accessed with ?. or null check
      if (parent is PropertyAccess) return;

      // Report if used directly in expression
      if (parent is NamedExpression || parent is ArgumentList) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Stepper widget lacks validation in onStepContinue.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Steppers should validate the current step before allowing progression.
/// Without validation, users can skip required fields.
///
/// **BAD:**
/// ```dart
/// Stepper(
///   onStepContinue: () {
///     setState(() => _currentStep++);
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Stepper(
///   onStepContinue: () {
///     if (_formKeys[_currentStep].currentState!.validate()) {
///       setState(() => _currentStep++);
///     }
///   },
/// )
/// ```
class RequireStepperValidationRule extends SaropaLintRule {
  const RequireStepperValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_stepper_validation',
    problemMessage:
        '[require_stepper_validation] Stepper onStepContinue callback does not validate form input before proceeding. This can allow users to advance with incomplete or invalid data, leading to errors or inconsistent state. {v3}',
    correctionMessage:
        'Add form validation logic in the onStepContinue callback to ensure all required fields are valid before allowing the user to proceed to the next step. This prevents incomplete or invalid submissions and improves data integrity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Stepper') return;

      // Check onStepContinue callback
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onStepContinue') {
          final Expression callback = arg.expression;
          if (callback is FunctionExpression) {
            final String bodySource = callback.body.toSource();

            // Check for validation patterns
            final bool hasValidation = bodySource.contains('validate()') ||
                bodySource.contains('isValid') ||
                bodySource.contains('canProceed') ||
                bodySource.contains('if (');

            if (!hasValidation) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when multi-step flow lacks a progress indicator.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Users need to know where they are in a multi-step process.
/// Show step count or progress indicator.
///
/// **BAD:**
/// ```dart
/// Column(children: [
///   if (step == 1) Step1Page(),
///   if (step == 2) Step2Page(),
///   if (step == 3) Step3Page(),
/// ])
/// ```
///
/// **GOOD:**
/// ```dart
/// Column(children: [
///   LinearProgressIndicator(value: step / totalSteps),
///   Text('Step $step of $totalSteps'),
///   if (step == 1) Step1Page(),
///   // ...
/// ])
/// ```
class RequireStepCountIndicatorRule extends SaropaLintRule {
  const RequireStepCountIndicatorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_step_count_indicator',
    problemMessage:
        '[require_step_count_indicator] Multi-step flow with 3+ conditional step views lacks a progress indicator. Users have no visibility into how many steps remain, leading to abandonment when the process feels open-ended. {v2}',
    correctionMessage:
        'Add a LinearProgressIndicator, Stepper widget, or "Step X of Y" text label so users know their current position and how many steps remain in the flow.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final FunctionBody? body = node.body;
      if (body == null) return;

      final String bodySource = body.toSource();

      // Check for multi-step patterns
      final bool hasMultipleSteps =
          RegExp(r'step\s*==\s*\d').allMatches(bodySource).length >= 3;

      if (!hasMultipleSteps) return;

      // Check for progress indicator
      final bool hasProgressIndicator =
          bodySource.contains('ProgressIndicator') ||
              bodySource.contains('Stepper') ||
              bodySource.contains('Step ') ||
              bodySource.contains('of \$') ||
              bodySource.contains('totalSteps') ||
              bodySource.contains('stepCount');

      if (!hasProgressIndicator) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

// =============================================================================
// Part 5 Rules: go_router Navigation Rules
// =============================================================================

/// Warns when GoRouter is created inline in build() method.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Creating GoRouter in build() causes issues with hot reload and state.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return MaterialApp.router(
///     routerConfig: GoRouter(routes: [...]), // Hot reload issues!
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final GoRouter _router = GoRouter(routes: [...]);
///
/// Widget build(BuildContext context) {
///   return MaterialApp.router(routerConfig: _router);
/// }
/// ```
class AvoidGoRouterInlineCreationRule extends SaropaLintRule {
  const AvoidGoRouterInlineCreationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_go_router_inline_creation',
    problemMessage:
        '[avoid_go_router_inline_creation] GoRouter instance created inside build() is destroyed and recreated on every widget rebuild. This resets all navigation state including the current route stack, destroys in-flight transitions, breaks hot reload during development, and causes users to lose their navigation position whenever the parent widget rebuilds. {v3}',
    correctionMessage:
        'Create the GoRouter instance as a final field in the State class or initialize it in initState() so the router persists across rebuilds and preserves navigation state.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GoRouter') return;

      // Only apply to files that import go_router
      if (!fileImportsPackage(node, PackageImports.goRouter)) return;

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when GoRouter is configured without error handler.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Without an error handler, unknown routes show a blank screen.
///
/// **BAD:**
/// ```dart
/// GoRouter(routes: myRoutes)
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRouter(
///   routes: myRoutes,
///   errorBuilder: (context, state) => ErrorPage(state.error),
/// )
/// ```
class RequireGoRouterErrorHandlerRule extends SaropaLintRule {
  const RequireGoRouterErrorHandlerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_go_router_error_handler',
    problemMessage:
        '[require_go_router_error_handler] GoRouter instance lacks an errorBuilder or errorPageBuilder parameter. When a user navigates to an undefined path via deep link, push notification, or typo, the router displays a blank white screen with no explanation or way to recover. {v3}',
    correctionMessage:
        'Add an errorBuilder parameter that returns a user-friendly error page with a message explaining the route was not found and a button to navigate back to the home screen.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GoRouter') return;

      // Only apply to files that import go_router
      if (!fileImportsPackage(node, PackageImports.goRouter)) return;

      // Check for error handler
      bool hasErrorHandler = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'errorBuilder' || name == 'errorPageBuilder') {
            hasErrorHandler = true;
            break;
          }
        }
      }

      if (!hasErrorHandler) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when GoRouter with auth doesn't have refreshListenable.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Auth state changes should refresh the router to update protected routes.
///
/// **BAD:**
/// ```dart
/// GoRouter(
///   redirect: (context, state) => authState.isLoggedIn ? null : '/login',
///   routes: [...],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRouter(
///   redirect: (context, state) => authState.isLoggedIn ? null : '/login',
///   refreshListenable: authState, // Refreshes on auth changes
///   routes: [...],
/// )
/// ```
class RequireGoRouterRefreshListenableRule extends SaropaLintRule {
  const RequireGoRouterRefreshListenableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_go_router_refresh_listenable',
    problemMessage:
        '[require_go_router_refresh_listenable] GoRouter has a redirect callback but no refreshListenable. When authentication state changes (login, logout, token expiry), the router does not re-evaluate redirects, leaving users stranded on protected pages after logout or blocked from authenticated pages after login. {v3}',
    correctionMessage:
        'Add a refreshListenable parameter pointing to your auth state ChangeNotifier so the router re-evaluates redirect logic whenever authentication state changes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GoRouter') return;

      // Only apply to files that import go_router
      if (!fileImportsPackage(node, PackageImports.goRouter)) return;

      bool hasRedirect = false;
      bool hasRefreshListenable = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'redirect') hasRedirect = true;
          if (name == 'refreshListenable') hasRefreshListenable = true;
        }
      }

      if (hasRedirect && !hasRefreshListenable) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when string literals are used in go_router navigation.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Type-safe navigation with go_router_builder is preferred.
///
/// **BAD:**
/// ```dart
/// context.go('/users/123/profile');
/// context.push('/settings');
/// ```
///
/// **GOOD:**
/// ```dart
/// context.go(UserProfileRoute(userId: '123').location);
/// // Or with go_router_builder:
/// UserProfileRoute(userId: '123').go(context);
/// ```
class AvoidGoRouterStringPathsRule extends SaropaLintRule {
  const AvoidGoRouterStringPathsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_go_router_string_paths',
    problemMessage:
        '[avoid_go_router_string_paths] String literal used as a navigation path in go_router. Hardcoded path strings are error-prone, bypass compile-time validation, and break silently when route definitions change. {v3}',
    correctionMessage:
        'Use go_router_builder to generate typed route classes that provide compile-time safety, auto-complete support, and catch route path mismatches at build time.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _navigationMethods = <String>{
    'go',
    'goNamed',
    'push',
    'pushNamed',
    'pushReplacement',
    'pushReplacementNamed',
    'replace',
    'replaceNamed',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_navigationMethods.contains(methodName)) return;

      // Only apply to files that import go_router
      if (!fileImportsPackage(node, PackageImports.goRouter)) return;

      // Check if target is context (go_router extension methods)
      final Expression? target = node.target;
      if (target == null) return;
      // Use type-based check for BuildContext
      if (target is! SimpleIdentifier || target.name != 'context') return;

      // Check first argument for string literal
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is SimpleStringLiteral ||
          firstArg is StringInterpolation ||
          firstArg is AdjacentStrings) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT Part 7 Rules
// =============================================================================

/// Suggests using go_router redirect instead of auth checks in page builders.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: go_router_auth_redirect, auth_in_redirect
///
/// Authentication logic belongs in go_router's redirect callback, not in
/// individual page builders. Centralizing auth checks improves maintainability.
///
/// **BAD:**
/// ```dart
/// GoRoute(
///   path: '/profile',
///   builder: (context, state) {
///     if (!authService.isLoggedIn) {
///       return LoginPage(); // Auth check in builder
///     }
///     return ProfilePage();
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRouter(
///   redirect: (context, state) {
///     if (!authService.isLoggedIn && state.matchedLocation != '/login') {
///       return '/login';
///     }
///     return null;
///   },
///   routes: [
///     GoRoute(path: '/profile', builder: (_, __) => ProfilePage()),
///   ],
/// )
/// ```
class PreferGoRouterRedirectAuthRule extends SaropaLintRule {
  const PreferGoRouterRedirectAuthRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_go_router_redirect_auth',
    problemMessage:
        '[prefer_go_router_redirect_auth] Authentication check detected inside a GoRoute builder instead of the router-level redirect callback. Scattering auth logic across individual page builders duplicates code, creates inconsistent enforcement, and allows new routes to accidentally skip authentication. {v3}',
    correctionMessage:
        'Move authentication logic to the GoRouter redirect parameter so all routes are protected by a single, centralized auth check that runs before any page builder executes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'GoRoute') return;

      // Only apply to files that import go_router
      if (!fileImportsPackage(node, PackageImports.goRouter)) return;

      // Find builder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final Expression builderExpr = arg.expression;

          // Check if builder contains auth-related checks
          final String builderSource = builderExpr.toSource().toLowerCase();

          // cspell:ignore isloggedin isauthenticated isauth currentuser authstate
          // Look for common auth patterns
          if ((builderSource.contains('isloggedin') ||
                  builderSource.contains('isauthenticated') ||
                  builderSource.contains('isauth') ||
                  builderSource.contains('currentuser') ||
                  builderSource.contains('authstate')) &&
              (builderSource.contains('if ') || builderSource.contains('?'))) {
            reporter.atNode(arg, code);
          }
        }
      }
    });
  }
}

/// Warns when go_router path parameters are used without type conversion.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: typed_go_router_params, go_router_param_types
///
/// Path parameters from go_router are strings. Using them without parsing
/// can lead to runtime errors when the code expects other types.
///
/// **BAD:**
/// ```dart
/// GoRoute(
///   path: '/user/:id',
///   builder: (context, state) {
///     final int userId = state.pathParameters['id']; // Type error!
///     return UserPage(userId: userId);
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRoute(
///   path: '/user/:id',
///   builder: (context, state) {
///     final userId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
///     return UserPage(userId: userId);
///   },
/// )
/// ```
class RequireGoRouterTypedParamsRule extends SaropaLintRule {
  const RequireGoRouterTypedParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_go_router_typed_params',
    problemMessage:
        '[require_go_router_typed_params] go_router pathParameters value accessed without type conversion. All path parameters are strings, and assigning them directly to int, double, or bool variables causes a runtime TypeError that crashes the app when users navigate to the route. {v2}',
    correctionMessage:
        'Parse path parameters with int.tryParse(), double.tryParse(), or a custom parser, and provide a fallback default value to handle malformed or missing input safely.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      // Only apply to files that import go_router
      if (!fileImportsPackage(node, PackageImports.goRouter)) return;

      // Check if accessing pathParameters
      final Expression? target = node.target;
      if (target is! PrefixedIdentifier) return;

      if (target.identifier.name != 'pathParameters') return;

      // Check parent - are we inside a tryParse or similar?
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodInvocation) {
          final String methodName = current.methodName.name.toLowerCase();

          // cspell:ignore tryparse
          if (methodName.contains('parse') ||
              methodName.contains('tryparse') ||
              methodName == 'tostring') {
            return; // Already being parsed
          }
        }
        if (current is VariableDeclaration) {
          // Check if type is String
          final AstNode? varDeclList = current.parent;
          if (varDeclList is VariableDeclarationList) {
            final TypeAnnotation? type = varDeclList.type;
            if (type != null && type.toSource() == 'String') {
              return; // Explicitly typed as String, OK
            }
            // Check for var/final with String inference
            final Expression? initializer = current.initializer;
            if (initializer != null) {
              final String initSource = initializer.toSource();
              if (initSource.contains('?? \'') ||
                  initSource.contains("?? '") ||
                  initSource.contains('?? ""') ||
                  initSource.contains('toString()')) {
                return; // Has null default string, likely OK
              }
            }
          }
          break;
        }
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when go_router extra parameter is Map or dynamic instead of typed.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
///
/// Using untyped extra parameters leads to runtime errors and makes code
/// harder to maintain. Use a typed class for type safety.
///
/// **BAD:**
/// ```dart
/// context.go('/profile', extra: {'userId': 123, 'name': 'John'});
///
/// // In route builder:
/// final extra = state.extra as Map<String, dynamic>; // Unsafe cast
/// final userId = extra['userId'] as int; // Another unsafe cast
/// ```
///
/// **GOOD:**
/// ```dart
/// class ProfileParams {
///   final int userId;
///   final String name;
///   ProfileParams({required this.userId, required this.name});
/// }
///
/// context.go('/profile', extra: ProfileParams(userId: 123, name: 'John'));
///
/// // In route builder:
/// final params = state.extra as ProfileParams; // Single typed cast
/// ```
class PreferGoRouterExtraTypedRule extends SaropaLintRule {
  const PreferGoRouterExtraTypedRule() : super(code: _code);

  /// Code quality issue - type safety for navigation.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'prefer_go_router_extra_typed',
    problemMessage:
        '[prefer_go_router_extra_typed] go_router extra parameter passes a Map or dynamic value instead of a typed class. Untyped extras require unsafe casts at the destination route, causing runtime ClassCastException crashes when the map structure changes or keys are misspelled. {v2}',
    correctionMessage:
        'Create a dedicated data class for the extra parameter and cast to that type in the route builder. This provides compile-time field validation and eliminates unsafe string-keyed map lookups.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _goRouterMethods = <String>{
    'go',
    'goNamed',
    'push',
    'pushNamed',
    'pushReplacement',
    'pushReplacementNamed',
    'replace',
    'replaceNamed',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_goRouterMethods.contains(methodName)) return;

      // Look for extra parameter
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'extra') continue;

        final Expression extraValue = arg.expression;

        // Check if extra is a Map literal
        if (extraValue is SetOrMapLiteral && extraValue.isMap) {
          reporter.atNode(arg, code);
          return;
        }

        // Check for explicit Map type cast or construction
        if (extraValue is AsExpression) {
          final String typeStr = extraValue.type.toSource();
          if (typeStr.startsWith('Map<') || typeStr == 'dynamic') {
            reporter.atNode(arg, code);
            return;
          }
        }

        // Check if extra is a variable with Map type
        if (extraValue is SimpleIdentifier) {
          final DartType? type = extraValue.staticType;
          if (type != null) {
            final String typeStr = type.getDisplayString();
            if (typeStr.startsWith('Map<') ||
                typeStr == 'dynamic' ||
                typeStr == 'Object?' ||
                typeStr == 'Object') {
              reporter.atNode(arg, code);
              return;
            }
          }
        }

        // Check for Map constructor
        if (extraValue is InstanceCreationExpression) {
          final String typeName = extraValue.constructorName.type.name2.lexeme;
          if (typeName == 'Map' || typeName == 'HashMap') {
            reporter.atNode(arg, code);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// Navigation Safety Rules
// =============================================================================

/// Warns when Navigator.pop() is used without checking if it can pop.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// Using Navigator.pop() directly can crash the app if there's no route to pop.
/// Use Navigator.maybePop() which safely checks before popping.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     Navigator.pop(context); // Crashes if no route to pop!
///   },
///   child: Text('Back'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     Navigator.maybePop(context); // Safely checks before popping
///   },
///   child: Text('Back'),
/// )
/// // Or check explicitly:
/// ElevatedButton(
///   onPressed: () {
///     if (Navigator.canPop(context)) {
///       Navigator.pop(context);
///     }
///   },
///   child: Text('Back'),
/// )
/// ```
class PreferMaybePopRule extends SaropaLintRule {
  const PreferMaybePopRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_maybe_pop',
    problemMessage:
        '[prefer_maybe_pop] Navigator.pop() called without verifying that a route exists on the navigation stack to pop. When the stack is empty or contains only the root route, this call throws a FlutterError at runtime, crashing the app. On Android, this also bypasses the system back button contract, preventing the app from exiting gracefully. {v3}',
    correctionMessage:
        'Replace Navigator.pop(context) with Navigator.maybePop(context), or check canPop() before calling pop. This prevents runtime errors and ensures your app only attempts to pop routes when it is safe to do so.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Navigator.pop or Navigator.of(context).pop
      if (methodName != 'pop') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check if target is Navigator or Navigator.of(...)
      bool isNavigatorPop = false;

      if (target is SimpleIdentifier && target.name == 'Navigator') {
        isNavigatorPop = true;
      } else if (target is MethodInvocation) {
        // Navigator.of(context).pop()
        final Expression? nestedTarget = target.target;
        if (nestedTarget is SimpleIdentifier &&
            nestedTarget.name == 'Navigator' &&
            target.methodName.name == 'of') {
          isNavigatorPop = true;
        }
      } else if (target is PrefixedIdentifier) {
        // Could be navigator.pop where navigator is a NavigatorState
        final String prefix = target.prefix.name;
        if (prefix == 'Navigator') {
          isNavigatorPop = true;
        }
      }

      if (!isNavigatorPop) return;

      // Check if there's a canPop check before this pop
      // Look for if (Navigator.canPop(context)) or similar patterns
      AstNode? current = node.parent;
      while (current != null) {
        if (current is IfStatement) {
          final String condition = current.expression.toSource();
          if (condition.contains('canPop') ||
              condition.contains('Navigator.canPop') ||
              condition.contains('navigator.canPop')) {
            // There's a canPop check, this is safe
            return;
          }
        }
        // Don't traverse too far up
        if (current is FunctionBody || current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }

      // Check if this pop is inside a WillPopScope or PopScope callback
      // where the framework already handles the logic
      current = node.parent;
      while (current != null) {
        if (current is NamedExpression) {
          final String paramName = current.name.label.name;
          if (paramName == 'onPopInvoked' ||
              paramName == 'onWillPop' ||
              paramName == 'onPopInvokedWithResult') {
            // Inside pop handling callback, this is intentional
            return;
          }
        }
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceWithMaybePopFix()];
}

class _ReplaceWithMaybePopFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.methodName.name != 'pop') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with maybePop',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'maybePop',
        );
      });
    });
  }
}

/// Warns when launchUrl is used with string parsing instead of Uri objects.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: url_launcher_uri, launch_with_uri
///
/// Using Uri objects instead of parsing strings reduces parsing overhead
/// and provides compile-time validation of URL structure.
///
/// **BAD:**
/// ```dart
/// await launchUrl(Uri.parse('https://example.com'));
/// ```
///
/// **GOOD:**
/// ```dart
/// final uri = Uri.https('example.com', '/path');
/// await launchUrl(uri);
/// ```
class PreferUrlLauncherUriOverStringRule extends SaropaLintRule {
  const PreferUrlLauncherUriOverStringRule() : super(code: _code);

  /// Crash path - malformed URI throws FormatException at runtime.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_url_launcher_uri_over_string',
    problemMessage:
        '[prefer_url_launcher_uri_over_string] launchUrl called with Uri.parse() on a string literal instead of constructing a Uri object directly. Uri.parse() defers validation to runtime, where malformed strings throw FormatException and crash the app. {v2}',
    correctionMessage:
        'Replace Uri.parse() with Uri.https() or Uri.http() constructors that validate the URL structure at compile time and auto-encode query parameters correctly.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'launchUrl' &&
          node.methodName.name != 'launch' &&
          node.methodName.name != 'canLaunchUrl') {
        return;
      }

      // Check if argument is Uri.parse()
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is MethodInvocation && firstArg.methodName.name == 'parse') {
        final Expression? target = firstArg.target;
        if (target is SimpleIdentifier && target.name == 'Uri') {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }
}

/// Warns about potential confusion between go() and push() in GoRouter.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: go_router_navigation, go_vs_push
///
/// go() replaces the entire stack, push() adds to it. Using the wrong one
/// can cause unexpected navigation behavior.
///
/// **Use go() when:** You want to replace the current route completely
/// **Use push() when:** You want to add to the navigation stack
///
/// **SUSPICIOUS (may want push instead of go):**
/// ```dart
/// context.go('/details/$id'); // Replaces stack - back button won't work
/// ```
///
/// **BETTER:**
/// ```dart
/// context.push('/details/$id'); // Adds to stack - back button works
/// ```
class AvoidGoRouterPushReplacementConfusionRule extends SaropaLintRule {
  const AvoidGoRouterPushReplacementConfusionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_go_router_push_replacement_confusion',
    problemMessage:
        '[avoid_go_router_push_replacement_confusion] context.go() used to navigate to a detail route with a dynamic ID parameter. go() replaces the entire navigation stack, destroying the back button history and preventing users from returning to the previous screen. {v2}',
    correctionMessage:
        'Replace context.go() with context.push() for detail routes so the previous screen remains on the stack and the back button navigates users to their prior location.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Route path segments that typically represent detail/item views
  /// where push() is usually more appropriate than go().
  static const Set<String> _detailPathSegments = <String>{
    '/detail',
    '/details',
    '/item',
    '/view',
    '/edit',
    '/show',
    '/profile',
    '/settings/',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'go') return;

      // Check if it's called on context (context.go)
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      // Only match direct 'context' usage, not variables with "context" as substring
      if (targetSource != 'context') return;

      // Check if the path looks like a detail route
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression pathArg = args.arguments.first;
      final String pathSource = pathArg.toSource().toLowerCase();

      // Only flag if path contains both:
      // 1. A known detail-style path segment
      // 2. A dynamic parameter (interpolation)
      final bool hasDetailSegment = _detailPathSegments.any(
        (String segment) => pathSource.contains(segment),
      );

      final bool hasDynamicParam = pathSource.contains(r'$') ||
          pathSource.contains(':id') ||
          pathSource.contains(':userid') ||
          pathSource.contains(':itemid');

      // Only warn if it's clearly a detail route with dynamic ID
      if (hasDetailSegment && hasDynamicParam) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when URL strings are not properly encoded before launching.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: encode_url, url_encode_required, url_launcher_encoding
///
/// URLs with special characters must be encoded before using with url_launcher.
/// Unencoded URLs may fail to open or cause security issues.
///
/// **BAD:**
/// ```dart
/// await launchUrl(Uri.parse('https://example.com/search?q=$query')); // query may have spaces
/// ```
///
/// **GOOD:**
/// ```dart
/// await launchUrl(Uri.parse('https://example.com/search?q=${Uri.encodeComponent(query)}'));
/// // Or use Uri constructor which auto-encodes:
/// await launchUrl(Uri.https('example.com', '/search', {'q': query}));
/// ```
///
/// **Quick fix available:** Wraps interpolated variable with `Uri.encodeComponent()`.
class RequireUrlLauncherEncodingRule extends SaropaLintRule {
  const RequireUrlLauncherEncodingRule() : super(code: _code);

  /// Unencoded URLs fail or cause injection vulnerabilities.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_url_launcher_encoding',
    problemMessage:
        '[require_url_launcher_encoding] URL passed to launchUrl or canLaunchUrl contains string interpolation without Uri.encodeComponent(). Unencoded special characters (spaces, ampersands, Unicode) produce malformed URLs that fail to open, display incorrect content, or enable URL injection attacks where user input manipulates the destination path or query parameters. {v2}',
    correctionMessage:
        'Use Uri.encodeComponent() for query parameters or construct URLs with Uri.https() to ensure all parts are properly encoded. This prevents malformed URLs and potential security vulnerabilities.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for launchUrl, launch, openUrl
      if (methodName != 'launchUrl' &&
          methodName != 'launch' &&
          methodName != 'openUrl' &&
          methodName != 'canLaunchUrl') {
        return;
      }

      // Check if argument contains Uri.parse with string interpolation
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;

      // Check for Uri.parse('...$var...')
      if (firstArg is MethodInvocation && firstArg.methodName.name == 'parse') {
        final ArgumentList parseArgs = firstArg.argumentList;
        if (parseArgs.arguments.isEmpty) return;

        final Expression urlArg = parseArgs.arguments.first;
        if (urlArg is StringInterpolation) {
          // Check if interpolation uses encodeComponent
          final String source = urlArg.toSource();
          if (!source.contains('encodeComponent') &&
              !source.contains('encodeQueryComponent')) {
            reporter.atNode(urlArg, code);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_WrapWithEncodeComponentFix()];
}

class _WrapWithEncodeComponentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addStringInterpolation((StringInterpolation node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // Find interpolation elements that are simple identifiers (variables)
      for (final InterpolationElement element in node.elements) {
        if (element is InterpolationExpression) {
          final Expression expr = element.expression;
          if (expr is SimpleIdentifier) {
            final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
              message: 'Wrap ${expr.name} with Uri.encodeComponent()',
              priority: 80,
            );

            changeBuilder.addDartFileEdit((builder) {
              // Replace $varName with ${Uri.encodeComponent(varName)}
              builder.addSimpleReplacement(
                element.sourceRange,
                '\${Uri.encodeComponent(${expr.name})}',
              );
            });
            return; // Fix the first one found
          }
        }
      }

      // If no simple identifier found, add a `HACK` comment
      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for manual encoding review',
        priority: 70,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the statement containing this interpolation
        AstNode? current = node.parent;
        while (current != null && current is! Statement) {
          current = current.parent;
        }

        if (current != null) {
          builder.addSimpleInsertion(
            current.offset,
            '// HACK: Wrap interpolated values with Uri.encodeComponent()\n    ',
          );
        }
      });
    });
  }
}

/// Warns when navigating to nested routes without ensuring parent is in stack.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: nested_route_parent, route_hierarchy, go_router_nested
///
/// In go_router, navigating directly to a nested route without its parent
/// in the stack can cause back button issues and navigation errors.
///
/// **BAD:**
/// ```dart
/// // From unrelated screen:
/// context.go('/products/details/123'); // Parent '/products' may not be in stack
/// ```
///
/// **GOOD:**
/// ```dart
/// // Navigate to parent first, then to child
/// context.go('/products');
/// context.push('/products/details/123');
/// // Or ensure the route is designed for deep linking
/// ```
class AvoidNestedRoutesWithoutParentRule extends SaropaLintRule {
  const AvoidNestedRoutesWithoutParentRule() : super(code: _code);

  /// Broken back button navigation frustrates users.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_routes_without_parent',
    problemMessage:
        '[avoid_nested_routes_without_parent] context.go() navigates to a path with 3+ segments, which places users deep in the route hierarchy without parent routes on the stack. The back button skips intermediate screens, breaking expected navigation flow and disorienting users. {v2}',
    correctionMessage:
        'Use context.push() to preserve the navigation stack, or verify that your route hierarchy supports deep linking and restores parent routes automatically via ShellRoute.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'go' && node.methodName.name != 'goNamed') {
        return;
      }

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression pathArg = args.arguments.first;
      if (pathArg is! SimpleStringLiteral) return;

      final String path = pathArg.value;

      // Count path segments
      final List<String> segments =
          path.split('/').where((s) => s.isNotEmpty).toList();

      // Warn if navigating to path with 3+ segments (deeply nested)
      if (segments.length >= 3) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// prefer_shell_route_shared_layout
// =============================================================================

/// Use ShellRoute for shared AppBar/BottomNav instead of duplicating Scaffold.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Multiple routes with the same Scaffold layout cause code duplication
/// and inconsistent behavior. ShellRoute provides a shared wrapper.
///
/// **BAD:**
/// ```dart
/// GoRoute(path: '/home', builder: (_, __) => Scaffold(appBar: AppBar()...)),
/// GoRoute(path: '/settings', builder: (_, __) => Scaffold(appBar: AppBar()...)),
/// ```
///
/// **GOOD:**
/// ```dart
/// ShellRoute(
///   builder: (_, __, child) => Scaffold(appBar: AppBar(), body: child),
///   routes: [
///     GoRoute(path: '/home', ...),
///     GoRoute(path: '/settings', ...),
///   ],
/// )
/// ```
class PreferShellRouteSharedLayoutRule extends SaropaLintRule {
  const PreferShellRouteSharedLayoutRule() : super(code: _code);

  /// Code duplication and maintenance burden.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_shell_route_shared_layout',
    problemMessage:
        '[prefer_shell_route_shared_layout] GoRoute with Scaffold builder may duplicate layout code. Multiple routes with the same Scaffold layout cause code duplication and inconsistent behavior. ShellRoute provides a shared wrapper. {v2}',
    correctionMessage:
        'Use ShellRoute for shared AppBar/BottomNav layouts. Test the full navigation flow including back button and deep links.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GoRoute') return;

      // Check for builder parameter with Scaffold
      final ArgumentList args = node.argumentList;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();
          if (builderSource.contains('Scaffold(') &&
              (builderSource.contains('AppBar(') ||
                  builderSource.contains('BottomNavigationBar(') ||
                  builderSource.contains('NavigationBar('))) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// require_stateful_shell_route_tabs
// =============================================================================

/// Tab navigation should use StatefulShellRoute to preserve state.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Regular ShellRoute recreates child widgets on tab switch, losing state.
/// StatefulShellRoute preserves each tab's state.
///
/// **BAD:**
/// ```dart
/// ShellRoute(
///   builder: (_, __, child) => TabScaffold(child: child),
///   routes: [tab1Route, tab2Route],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// StatefulShellRoute.indexedStack(
///   builder: (_, __, navigationShell) => TabScaffold(shell: navigationShell),
///   branches: [branch1, branch2],
/// )
/// ```
class RequireStatefulShellRouteTabsRule extends SaropaLintRule {
  const RequireStatefulShellRouteTabsRule() : super(code: _code);

  /// Tab state loss on navigation.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_stateful_shell_route_tabs',
    problemMessage:
        '[require_stateful_shell_route_tabs] ShellRoute with tab-like navigation may lose state on tab switch. Regular ShellRoute recreates child widgets on tab switch, losing state. StatefulShellRoute preserves each tab\'s state. {v2}',
    correctionMessage:
        'Use StatefulShellRoute.indexedStack for preserving tab state. Test the full navigation flow including back button and deep links.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'ShellRoute') return;

      // Check for tab-related patterns in builder
      final ArgumentList args = node.argumentList;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();
          // Look for tab-related widgets
          if (builderSource.contains('BottomNavigationBar') ||
              builderSource.contains('NavigationBar') ||
              builderSource.contains('TabBar') ||
              builderSource.contains('IndexedStack')) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// require_go_router_fallback_route
// =============================================================================

/// Router should have catch-all or error route for unknown paths.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Without error handling, navigating to unknown paths crashes or shows
/// blank screens.
///
/// **BAD:**
/// ```dart
/// GoRouter(routes: [
///   GoRoute(path: '/', builder: ...),
///   // No fallback!
/// ])
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRouter(
///   errorBuilder: (context, state) => ErrorPage(),
///   routes: [...],
/// )
/// ```
class RequireGoRouterFallbackRouteRule extends SaropaLintRule {
  const RequireGoRouterFallbackRouteRule() : super(code: _code);

  /// User-facing errors on invalid navigation.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_go_router_fallback_route',
    problemMessage:
        '[require_go_router_fallback_route] GoRouter configuration without errorBuilder or errorPageBuilder has no fallback for unmatched routes. When users navigate to a non-existent path via deep link, push notification, or typo, the router throws an unhandled exception that crashes the app instead of showing a helpful error page. {v2}',
    correctionMessage:
        'Add errorBuilder: (context, state) => NotFoundPage() or errorPageBuilder to display a user-friendly error screen when navigation targets an undefined route.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GoRouter') return;

      // Check for error handling parameters
      final ArgumentList args = node.argumentList;
      bool hasErrorHandler = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'errorBuilder' ||
              paramName == 'errorPageBuilder' ||
              paramName == 'onException') {
            hasErrorHandler = true;
            break;
          }
        }
      }

      if (!hasErrorHandler) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// NEW ROADMAP STAR RULES - Navigation Rules
// =============================================================================

/// Warns when RouteSettings.name is not provided for analytics tracking.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Route names are essential for analytics, debugging, and deep linking.
/// Always provide meaningful route names.
///
/// **BAD:**
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => DetailsPage()),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => DetailsPage(),
///     settings: RouteSettings(name: '/details'),
///   ),
/// );
/// ```
class PreferRouteSettingsNameRule extends SaropaLintRule {
  const PreferRouteSettingsNameRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_route_settings_name',
    problemMessage:
        '[prefer_route_settings_name] MaterialPageRoute without RouteSettings.name. '
        'Analytics and debugging will be harder. {v2}',
    correctionMessage:
        'Add settings: RouteSettings(name: "/route_name") to the route.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _routeTypes = <String>{
    'MaterialPageRoute',
    'CupertinoPageRoute',
    'PageRouteBuilder',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_routeTypes.contains(typeName)) return;

      // Check for settings parameter
      final ArgumentList args = node.argumentList;
      bool hasSettings = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'settings') {
          hasSettings = true;
          break;
        }
      }

      if (!hasSettings) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// avoid_navigator_context_issue
// =============================================================================

/// Navigator.of() needs proper context from the widget tree.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Using context from a different part of the tree (like a GlobalKey's
/// `currentContext`) can cause navigation failures or unexpected behavior.
/// The widget referenced by the GlobalKey may not be mounted, may be in a
/// different Navigator scope, or may have been disposed.
///
/// **Why this matters:**
/// - `currentContext` can be null if the widget isn't in the tree
/// - The context may belong to a different Navigator (nested navigators)
/// - Force-unwrapping (`!`) will crash if the widget was disposed
/// - Navigation may silently fail or go to the wrong navigator
///
/// **Note:** This rule does NOT flag `Scrollable.ensureVisible()` which
/// legitimately requires `GlobalKey.currentContext` to scroll to a widget.
///
/// **BAD:**
/// ```dart
/// // GlobalKey context - may not be in tree or wrong navigator
/// Navigator.of(scaffoldKey.currentContext!).push(route);
///
/// // NavigatorState.context - same issues
/// final nav = Navigator.of(context);
/// // ... later in callback ...
/// nav.context; // Stale reference
/// ```
///
/// **GOOD:**
/// ```dart
/// // Direct BuildContext from widget tree
/// Navigator.of(context).push(route);
///
/// // With mounted check for async scenarios
/// if (context.mounted) {
///   Navigator.of(context).push(route);
/// }
/// ```
class AvoidNavigatorContextIssueRule extends SaropaLintRule {
  const AvoidNavigatorContextIssueRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_navigator_context_issue',
    problemMessage:
        '[avoid_navigator_context_issue] Using context from GlobalKey for '
        'navigation can fail if widget is not in tree. {v2}',
    correctionMessage:
        'Use the BuildContext parameter directly instead of currentContext.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Navigator.of() or Navigator.push() etc.
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();

      // Only flag Navigator operations
      if (targetSource != 'Navigator' &&
          !targetSource.startsWith('Navigator.')) {
        return;
      }

      // Check arguments for currentContext usage
      final ArgumentList args = node.argumentList;
      for (final Expression arg in args.arguments) {
        if (_hasProblematicContextUsage(arg.toSource())) {
          reporter.atNode(arg, code);
          return;
        }
      }
    });

    // Check Navigator-related instance creations (routes, pages)
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String constructorName = node.constructorName.toSource();

      // Only check Navigator-related instance creations
      if (!constructorName.endsWith('Route') &&
          !constructorName.endsWith('Page') &&
          !constructorName.startsWith('Navigator')) {
        return;
      }

      for (final Expression arg in node.argumentList.arguments) {
        if (_hasProblematicContextUsage(arg.toSource())) {
          reporter.atNode(arg, code);
        }
      }
    });
  }

  /// Check for problematic context patterns in source code.
  ///
  /// Returns true if the source contains:
  /// - `.currentContext` (GlobalKey context access)
  /// - `navigator.context` or `Navigator.of(...).context`
  bool _hasProblematicContextUsage(String source) {
    // Check for GlobalKey.currentContext patterns
    if (source.contains('.currentContext')) {
      return true;
    }

    // Check specifically for navigator.context (NavigatorState's context)
    // but not general .context usage or property names containing "context"
    if (source.contains('navigator.context') ||
        (source.contains('Navigator.of(') && source.contains(').context'))) {
      return true;
    }

    return false;
  }
}

// =============================================================================
// require_pop_result_type
// =============================================================================

/// MaterialPageRoute should specify result type when expecting a return value.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// When using Navigator.pop(context, result), the route should have
/// a type parameter for type safety.
///
/// **BAD:**
/// ```dart
/// final result = await Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => SelectionPage()),  // Untyped!
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await Navigator.push<String>(
///   context,
///   MaterialPageRoute<String>(builder: (_) => SelectionPage()),
/// );
/// ```
class RequirePopResultTypeRule extends SaropaLintRule {
  const RequirePopResultTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_pop_result_type',
    problemMessage:
        '[require_pop_result_type] Awaited route push without type parameter. '
        'Return type will be dynamic. {v2}',
    correctionMessage:
        'Add type parameter: Navigator.push<ReturnType>(...) and '
        'MaterialPageRoute<ReturnType>(...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAwaitExpression((AwaitExpression node) {
      final Expression expr = node.expression;
      if (expr is! MethodInvocation) return;

      // Check for Navigator.push
      final String methodName = expr.methodName.name;
      if (methodName != 'push' &&
          methodName != 'pushNamed' &&
          methodName != 'pushReplacement') {
        return;
      }

      final Expression? target = expr.target;
      if (target == null) return;

      // Check if it's a Navigator call
      final String targetSource = target.toSource();
      if (targetSource != 'Navigator' &&
          !targetSource.startsWith('Navigator.')) {
        return;
      }

      // Check if type argument is provided
      final TypeArgumentList? typeArgs = expr.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// avoid_push_replacement_misuse
// =============================================================================

/// Understand push vs pushReplacement vs pushAndRemoveUntil.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Using the wrong navigation method can cause unexpected back button
/// behavior or memory issues.
///
/// **BAD:**
/// ```dart
/// // Using pushReplacement for a detail page that should allow going back
/// Navigator.pushReplacement(context, route);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use push for screens that should stack
/// Navigator.push(context, route);
///
/// // Use pushReplacement only for login->home transitions
/// Navigator.pushReplacement(context, homeRoute);
/// ```
class AvoidPushReplacementMisuseRule extends SaropaLintRule {
  const AvoidPushReplacementMisuseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_push_replacement_misuse',
    problemMessage:
        '[avoid_push_replacement_misuse] `[HEURISTIC]` pushReplacement removes '
        'current route from stack. User cannot go back. {v2}',
    correctionMessage:
        'Use Navigator.push() if user should be able to go back. Use '
        'pushReplacement only for login->home or similar transitions.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Route names that typically shouldn't use pushReplacement
  static const Set<String> _normalRouteIndicators = <String>{
    'detail',
    'details',
    'view',
    'edit',
    'form',
    'settings',
    'profile',
    'item',
    'product',
    'order',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'pushReplacement' &&
          methodName != 'pushReplacementNamed') {
        return;
      }

      // Get the route being pushed
      final ArgumentList args = node.argumentList;
      for (final Expression arg in args.arguments) {
        final String argSource = arg.toSource().toLowerCase();

        // Check if route name suggests it shouldn't use replacement
        for (final String indicator in _normalRouteIndicators) {
          if (argSource.contains(indicator)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// avoid_nested_navigators_misuse
// =============================================================================

/// Nested Navigators need careful WillPopScope handling.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// When using nested Navigators (e.g., tabs with their own navigation stacks),
/// the back button behavior can confuse users if not handled properly.
///
/// **BAD:**
/// ```dart
/// TabBarView(
///   children: [
///     Navigator(key: _tab1Key, ...),
///     Navigator(key: _tab2Key, ...),
///   ],
/// )
/// // No WillPopScope handling!
/// ```
///
/// **GOOD:**
/// ```dart
/// WillPopScope(
///   onWillPop: () async {
///     final navigator = _getCurrentNavigator();
///     if (navigator.canPop()) {
///       navigator.pop();
///       return false;
///     }
///     return true;
///   },
///   child: TabBarView(
///     children: [
///       Navigator(key: _tab1Key, ...),
///       Navigator(key: _tab2Key, ...),
///     ],
///   ),
/// )
/// ```
class AvoidNestedNavigatorsMisuseRule extends SaropaLintRule {
  const AvoidNestedNavigatorsMisuseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_nested_navigators_misuse',
    problemMessage: '[avoid_nested_navigators_misuse] Nested Navigator without '
        'WillPopScope/PopScope. Back button may behave unexpectedly. {v2}',
    correctionMessage:
        'Wrap with WillPopScope/PopScope to handle back navigation properly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String constructorName = node.constructorName.type.name2.lexeme;
      if (constructorName != 'Navigator') return;

      // Check if this Navigator is inside TabBarView or similar
      AstNode? current = node.parent;
      bool isNested = false;
      bool hasPopScope = false;

      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name2.lexeme;

          if (parentType == 'TabBarView' ||
              parentType == 'PageView' ||
              parentType == 'IndexedStack') {
            isNested = true;
          }

          if (parentType == 'WillPopScope' || parentType == 'PopScope') {
            hasPopScope = true;
          }
        }
        current = current.parent;
      }

      if (isNested && !hasPopScope) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// require_deep_link_testing
// =============================================================================

/// Every route should be testable via deep link.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Routes only reachable through navigation chains break when users share
/// links or use app shortcuts.
///
/// **BAD:**
/// ```dart
/// // Route only accessible through navigation
/// Navigator.push(context, ProductDetailRoute(product));
/// // No deep link support!
/// ```
///
/// **GOOD:**
/// ```dart
/// // Route accessible via deep link
/// GoRouter(
///   routes: [
///     GoRoute(
///       path: '/product/:id',
///       builder: (context, state) =>
///         ProductDetailScreen(id: state.params['id']!),
///     ),
///   ],
/// )
/// ```
class RequireDeepLinkTestingRule extends SaropaLintRule {
  const RequireDeepLinkTestingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_deep_link_testing',
    problemMessage:
        '[require_deep_link_testing] `[HEURISTIC]` Route uses object parameter '
        'instead of ID. Consider using path parameters for deep link support. {v2}',
    correctionMessage:
        'Use path/query parameters (e.g., /product/:id) instead of passing '
        'full objects for better deep link support.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'push' && methodName != 'pushNamed') return;

      // Check if passing complex objects instead of IDs
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'arguments') {
          // Check if passing an object that's not a simple type
          final value = arg.expression;
          if (value is! SimpleStringLiteral &&
              value is! IntegerLiteral &&
              value is! DoubleLiteral &&
              value is! BooleanLiteral) {
            // Check if it looks like a model object
            final valueSource = value.toSource();
            if (!valueSource.contains('id:') && !valueSource.contains("'id'")) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// Navigation Result Handling Rules
// =============================================================================

/// Warns when Navigator.push() or Navigator.pushNamed() is called without
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// awaiting the result or assigning it to a variable.
///
/// Navigator.push returns a Future that resolves to the value passed to
/// Navigator.pop(). Ignoring this result means the calling screen cannot
/// react to what happened on the pushed screen.
///
/// **BAD:**
/// ```dart
/// Navigator.push(context, MaterialPageRoute(builder: (_) => EditPage()));
/// // Result from EditPage is lost!
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await Navigator.push<bool>(
///   context,
///   MaterialPageRoute(builder: (_) => EditPage()),
/// );
/// if (result == true) refreshData();
/// ```
class RequireNavigationResultHandlingRule extends SaropaLintRule {
  const RequireNavigationResultHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_navigation_result_handling',
    problemMessage:
        '[require_navigation_result_handling] Navigator push method is called as a fire-and-forget statement without awaiting or assigning its Future result. Navigator.push() returns a Future<T?> that resolves to the value passed to Navigator.pop(result). Ignoring this return value means the calling screen cannot react to user actions on the pushed screen, leading to stale UI, missed data updates, and broken back-navigation workflows that frustrate users. {v2}',
    correctionMessage:
        'Await the Navigator.push() call and handle the returned result, or assign it to a variable for later use. If no result is expected, add an explicit comment.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Navigator push methods that return results.
  static const Set<String> _pushMethods = <String>{
    'push',
    'pushNamed',
    'pushReplacement',
    'pushReplacementNamed',
    'pushAndRemoveUntil',
    'pushNamedAndRemoveUntil',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_pushMethods.contains(node.methodName.name)) return;

      // Check target is Navigator
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Navigator') return;

      // Check if it's an expression statement (not awaited, not assigned)
      final AstNode? parent = node.parent;
      if (parent is ExpressionStatement) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddAwaitToNavigatorPushFix()];
}

class _AddAwaitToNavigatorPushFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add await to handle navigation result',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.offset, 'await ');
      });
    });
  }
}

// =============================================================================
// GO ROUTER REDIRECT RULES
// =============================================================================

/// Warns when GoRouter is created without a redirect callback.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Authentication checks in GoRouter's `redirect` callback run before
/// `build()`, preventing a flash of protected content. If auth checks
/// are done in `build()` instead, users briefly see the protected page
/// before being redirected — a poor UX and a potential information leak.
///
/// **BAD:**
/// ```dart
/// GoRouter(
///   routes: [
///     GoRoute(path: '/home', builder: (_, __) => HomeScreen()),
///   ],
/// )
/// // Auth check done in HomeScreen.build()
/// ```
///
/// **GOOD:**
/// ```dart
/// GoRouter(
///   redirect: (context, state) {
///     if (!isLoggedIn) return '/login';
///     return null;
///   },
///   routes: [
///     GoRoute(path: '/home', builder: (_, __) => HomeScreen()),
///   ],
/// )
/// ```
class PreferGoRouterRedirectRule extends SaropaLintRule {
  const PreferGoRouterRedirectRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_go_router_redirect',
    problemMessage:
        '[prefer_go_router_redirect] GoRouter created without a redirect callback. Without redirect, authentication and authorization checks must happen in build(), which briefly shows the protected page before redirecting. Users see a flash of content they should not access, and crawlers or screen readers may capture protected information. Use the redirect callback to intercept navigation before any UI renders. {v1}',
    correctionMessage:
        'Add a redirect callback to GoRouter that checks authentication state and returns the login route for unauthenticated users.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GoRouter') return;

      // Check if redirect parameter is present
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'redirect') {
          return; // Has redirect, OK
        }
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, unused_element

/// Navigation lint rules for Flutter applications.
///
/// These rules help identify common navigation issues including unnamed
/// routes, missing error handlers, and context usage after navigation.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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

  static const LintCode _code = LintCode(
    name: 'require_unknown_route_handler',
    problemMessage:
        'App has routes but no onUnknownRoute. Unknown routes will crash.',
    correctionMessage:
        'Add onUnknownRoute to handle undefined routes gracefully.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_context_after_navigation',
    problemMessage:
        'Using context after await navigation. Widget may be disposed.',
    correctionMessage: 'Add "if (!mounted) return;" before using context.',
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
      final String source = node.toSource();
      if (source.contains('context') || source.contains('Context')) {
        // Check if it's using context
        final Expression? target = node.target;
        if (target != null) {
          final String targetSource = target.toSource();
          if (targetSource == 'context' ||
              targetSource.contains('.of(context')) {
            reporter.atNode(node, code);
          }
        }
        // Check arguments for context
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is SimpleIdentifier && arg.name == 'context') {
            reporter.atNode(node, code);
            break;
          }
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

  static const LintCode _code = LintCode(
    name: 'require_route_transition_consistency',
    problemMessage: 'Mixed route transition types. Use consistent transitions.',
    correctionMessage:
        'Define transitions in ThemeData.pageTransitionsTheme for consistency.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_navigator_push_unnamed',
    problemMessage:
        'Navigator.push without named route. Use pushNamed or a router.',
    correctionMessage:
        'Define named routes in MaterialApp.routes or use a router package.',
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
      if (!targetSource.contains('Navigator')) return;

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

  static const LintCode _code = LintCode(
    name: 'require_route_guards',
    problemMessage: 'Protected route without authentication guard.',
    correctionMessage:
        'Add redirect callback to check authentication before accessing this route.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_circular_redirects',
    problemMessage:
        'Redirect may cause infinite loop. Always include conditional return null.',
    correctionMessage:
        'Ensure redirect callback returns null in some cases to break the chain.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_pop_without_result',
    problemMessage:
        'Navigator.push result may be null. Handle the case when user presses back.',
    correctionMessage:
        'Check if result is null before using it, or use type-safe routing.',
    errorSeverity: DiagnosticSeverity.INFO,
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
      if (!target.toSource().contains('Navigator')) return;

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

  static const LintCode _code = LintCode(
    name: 'prefer_shell_route_for_persistent_ui',
    problemMessage:
        'Multiple routes with same bottomNavigationBar. Use ShellRoute instead.',
    correctionMessage:
        'Wrap related routes in ShellRoute to share persistent UI elements.',
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
/// Deep links may reference content that doesn't exist or has been deleted.
/// Always handle the case where the linked content is unavailable.
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

  static const LintCode _code = LintCode(
    name: 'require_deep_link_fallback',
    problemMessage: 'Deep link handler should handle missing/invalid content.',
    correctionMessage:
        'Add fallback for when linked content is not found or unavailable.',
    errorSeverity: DiagnosticSeverity.INFO,
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

      final FunctionBody? body = node.body;
      if (body == null) return;

      final String bodySource = body.toSource();

      // Check for fallback patterns
      final bool hasFallback = bodySource.contains('NotFound') ||
          bodySource.contains('404') ||
          bodySource.contains('error') ||
          bodySource.contains('null)') ||
          bodySource.contains('== null') ||
          bodySource.contains('isEmpty') ||
          bodySource.contains('try') ||
          bodySource.contains('catch');

      if (!hasFallback) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

// cspell:ignore myapp
/// Warns when deep link contains sensitive parameters like password or token.
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

  static const LintCode _code = LintCode(
    name: 'avoid_deep_link_sensitive_params',
    problemMessage: 'Deep link should not contain sensitive parameters.',
    correctionMessage:
        'Do not pass passwords, tokens, or secrets via deep link.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_typed_route_params',
    problemMessage: 'Route parameter used without type conversion.',
    correctionMessage:
        'Use int.tryParse/double.tryParse for numeric parameters.',
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

  static const LintCode _code = LintCode(
    name: 'require_stepper_validation',
    problemMessage: 'Stepper onStepContinue should validate before proceeding.',
    correctionMessage: 'Add form validation in onStepContinue callback.',
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

  static const LintCode _code = LintCode(
    name: 'require_step_count_indicator',
    problemMessage: 'Multi-step flow should show progress indicator.',
    correctionMessage: 'Add step counter or progress indicator.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_go_router_inline_creation',
    problemMessage: 'GoRouter created in build(). Causes hot reload issues.',
    correctionMessage:
        'Create GoRouter as a field or in initState(), not in build().',
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

  static const LintCode _code = LintCode(
    name: 'require_go_router_error_handler',
    problemMessage:
        'GoRouter without error handler. Unknown routes show blank screen.',
    correctionMessage: 'Add errorBuilder or errorPageBuilder parameter.',
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

  static const LintCode _code = LintCode(
    name: 'require_go_router_refresh_listenable',
    problemMessage:
        'GoRouter with redirect but no refreshListenable. Auth changes won\'t refresh routes.',
    correctionMessage:
        'Add refreshListenable parameter to update routes on auth changes.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_go_router_string_paths',
    problemMessage:
        'String literal in navigation. Use typed routes for type safety.',
    correctionMessage:
        'Consider using go_router_builder for type-safe navigation.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_go_router_redirect_auth',
    problemMessage:
        'Auth check in page builder. Use redirect callback instead.',
    correctionMessage:
        'Move authentication logic to GoRouter\'s redirect parameter.',
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

  static const LintCode _code = LintCode(
    name: 'require_go_router_typed_params',
    problemMessage:
        'Path parameter used without type conversion. May cause runtime errors.',
    correctionMessage:
        'Use int.tryParse(), double.tryParse(), or other type conversion.',
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

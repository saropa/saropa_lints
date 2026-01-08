// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

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

import '../saropa_lint_rule.dart';

/// Warns when MaterialApp/CupertinoApp lacks onUnknownRoute.
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

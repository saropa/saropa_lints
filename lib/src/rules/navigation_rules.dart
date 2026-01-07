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
    correctionMessage: 'Add onUnknownRoute to handle undefined routes gracefully.',
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

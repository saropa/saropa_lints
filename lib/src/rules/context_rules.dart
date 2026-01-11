// ignore_for_file: depend_on_referenced_packages

/// BuildContext safety rules for Flutter applications.
///
/// These rules detect common misuses of BuildContext that can lead to
/// runtime crashes, memory leaks, or unpredictable behavior.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when BuildContext is stored in a field.
///
/// Alias: store_context, context_field, cache_context
///
/// BuildContext is tied to the widget tree lifecycle. Storing it in a field
/// can lead to using an invalid context after the widget is disposed,
/// causing crashes or incorrect behavior.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late BuildContext _savedContext; // DANGEROUS!
///
///   @override
///   void initState() {
///     super.initState();
///     _savedContext = context; // Storing context
///   }
///
///   void doSomething() {
///     Navigator.of(_savedContext).push(...); // May crash!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   void doSomething() {
///     if (!mounted) return;
///     Navigator.of(context).push(...); // Use context directly
///   }
/// }
/// ```
class AvoidStoringContextRule extends SaropaLintRule {
  const AvoidStoringContextRule() : super(code: _code);

  /// Storing context can cause crashes when widget is disposed.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_storing_context',
    problemMessage:
        'BuildContext should not be stored in fields. It may become invalid.',
    correctionMessage:
        'Use context directly where needed and check mounted before use.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Detect field declarations with BuildContext type
    context.registry.addFieldDeclaration((node) {
      for (final variable in node.fields.variables) {
        final type = node.fields.type?.toSource() ?? '';
        if (_isContextType(type)) {
          reporter.atNode(variable, code);
        }
      }
    });

    // Detect assignments to fields with context
    context.registry.addAssignmentExpression((node) {
      // Check if the right side is 'context'
      final rightSource = node.rightHandSide.toSource();
      if (rightSource != 'context') return;

      // Check if left side is a field (prefixed with this. or just a field)
      final left = node.leftHandSide;
      if (left is PrefixedIdentifier && left.prefix.name == 'this') {
        // this._context = context
        reporter.atNode(node, code);
      } else if (left is SimpleIdentifier) {
        // Check if it's assigning to a field (starts with _ or is a known field)
        final name = left.name;
        if (name.startsWith('_') || name.contains('context')) {
          // This is likely a field assignment
          // We need to verify it's inside a class method
          if (_isInsideClassMethod(node)) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  bool _isContextType(String type) {
    return type == 'BuildContext' ||
        type == 'BuildContext?' ||
        type == 'late BuildContext' ||
        type.contains('BuildContext');
  }

  bool _isInsideClassMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        // Check if method is inside a class
        AstNode? methodParent = current.parent;
        while (methodParent != null) {
          if (methodParent is ClassDeclaration) {
            return true;
          }
          methodParent = methodParent.parent;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when BuildContext is used after an await.
///
/// Alias: context_after_await, async_context, stale_context
///
/// After an await, the widget may have been disposed. Using context
/// after an await without checking mounted can cause crashes.
///
/// **BAD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   Navigator.of(context).push(...); // Context may be invalid!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (!mounted) return;
///   Navigator.of(context).push(...);
/// }
/// ```
class AvoidContextAcrossAsyncRule extends SaropaLintRule {
  const AvoidContextAcrossAsyncRule() : super(code: _code);

  /// Context after await can crash when widget disposed.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_context_across_async',
    problemMessage:
        'BuildContext used after await. Widget may be disposed by then.',
    correctionMessage: 'Check "if (!mounted) return;" before using context.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      // Only check async methods with block body
      if (node.body is! BlockFunctionBody) return;
      final body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      _checkAsyncBody(body.block, reporter);
    });

    // Also check function expressions (lambdas)
    context.registry.addFunctionExpression((node) {
      if (node.body is! BlockFunctionBody) return;
      final body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      _checkAsyncBody(body.block, reporter);
    });
  }

  /// Check an async function body for context usage after await.
  void _checkAsyncBody(Block block, SaropaDiagnosticReporter reporter) {
    bool seenAwait = false;
    bool hasGuard = false;

    for (final statement in block.statements) {
      // Check for await expressions in this statement
      final statementHasAwait = _containsAwait(statement);
      if (statementHasAwait) {
        seenAwait = true;
        hasGuard = false; // Reset guard after each await
        // Don't report context usage in the SAME statement as the await
        // (context passed as an argument to the await call is OK)
        continue;
      }

      // Check if this statement is an early return guard: if (!mounted) return;
      if (seenAwait && _isNegatedMountedGuard(statement)) {
        hasGuard = true;
        continue;
      }

      // Check if this statement is a positive mounted guard: if (mounted) { ... }
      // In this case, we should NOT report context usage inside the if block
      if (seenAwait && _isPositiveMountedGuard(statement)) {
        // Don't report anything inside the if (mounted) block
        continue;
      }

      // After await and no guard, report any context usage
      if (seenAwait && !hasGuard) {
        _reportContextUsage(statement, reporter);
      }
    }
  }

  /// Checks if statement contains an await expression.
  bool _containsAwait(Statement stmt) {
    bool found = false;
    stmt.visitChildren(_AwaitFinder(() => found = true));
    return found;
  }

  /// Checks if statement is `if (!mounted) return;` or `if (!mounted) throw;`
  bool _isNegatedMountedGuard(Statement stmt) {
    if (stmt is! IfStatement) return false;

    final condition = stmt.expression.toSource();
    // Check for !mounted or mounted == false patterns
    if (!condition.contains('mounted')) return false;

    final isNegated = condition.contains('!mounted') ||
        condition.contains('!this.mounted') ||
        condition.contains('!context.mounted') ||
        condition.contains('mounted == false') ||
        condition.contains('mounted==false');

    if (!isNegated) return false;

    // Check if then branch contains early exit (return or throw)
    final thenStmt = stmt.thenStatement;
    if (thenStmt is ReturnStatement) return true;
    if (thenStmt is ExpressionStatement &&
        thenStmt.expression is ThrowExpression) {
      return true;
    }
    if (thenStmt is Block && thenStmt.statements.length == 1) {
      final single = thenStmt.statements.first;
      if (single is ReturnStatement) return true;
      if (single is ExpressionStatement &&
          single.expression is ThrowExpression) {
        return true;
      }
    }
    return false;
  }

  /// Checks if statement is `if (mounted) { ... }` (positive check).
  /// Context usage inside this block is safe.
  bool _isPositiveMountedGuard(Statement stmt) {
    if (stmt is! IfStatement) return false;

    final condition = stmt.expression.toSource();
    // Check for just 'mounted' without negation
    if (!condition.contains('mounted')) return false;

    // Make sure it's NOT negated
    final isNegated = condition.contains('!mounted') ||
        condition.contains('!this.mounted') ||
        condition.contains('!context.mounted') ||
        condition.contains('mounted == false') ||
        condition.contains('mounted==false');

    // It should be a positive check like 'if (mounted)' or 'if (this.mounted)'
    return !isNegated;
  }

  /// Report any context usage in a statement (after await without guard).
  void _reportContextUsage(Statement stmt, SaropaDiagnosticReporter reporter) {
    stmt.visitChildren(_ContextUsageFinder(reporter, code));
  }
}

/// Visitor to find await expressions.
class _AwaitFinder extends RecursiveAstVisitor<void> {
  _AwaitFinder(this.onFound);
  final void Function() onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound();
    super.visitAwaitExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Don't descend into nested function expressions
    return;
  }
}

/// Visitor to find context usage and report it.
class _ContextUsageFinder extends RecursiveAstVisitor<void> {
  _ContextUsageFinder(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'context') {
      // Skip if this is part of a mounted check expression
      final parent = node.parent;
      if (parent != null) {
        final parentSource = parent.toSource();
        if (parentSource.contains('mounted')) {
          super.visitSimpleIdentifier(node);
          return;
        }
      }
      reporter.atNode(node, code);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Don't descend into nested function expressions (callbacks)
    // The context inside a builder callback is valid within that callback
    return;
  }
}

/// Warns when BuildContext is used in static methods.
///
/// Alias: static_context, context_in_static
///
/// Static methods don't have access to widget instance state, so they
/// can't check `mounted`. Context passed to static methods may become
/// invalid before or during method execution.
///
/// **BAD:**
/// ```dart
/// class MyHelper {
///   static void showError(BuildContext context, String message) {
///     ScaffoldMessenger.of(context).showSnackBar(...);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Option 1: Use instance methods with mounted check
/// void showError(String message) {
///   if (!mounted) return;
///   ScaffoldMessenger.of(context).showSnackBar(...);
/// }
///
/// // Option 2: Pass mounted state along with context
/// static void showError(BuildContext context, bool mounted, String message) {
///   if (!mounted) return;
///   ScaffoldMessenger.of(context).showSnackBar(...);
/// }
///
/// // Option 3: Use global navigator key for navigation
/// class AppNavigator {
///   static final navigatorKey = GlobalKey<NavigatorState>();
///   static void push(Widget page) {
///     navigatorKey.currentState?.push(...);
///   }
/// }
/// ```
class AvoidContextInStaticMethodsRule extends SaropaLintRule {
  const AvoidContextInStaticMethodsRule() : super(code: _code);

  /// Static methods can't check mounted state.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_context_in_static_methods',
    problemMessage:
        'BuildContext in static method cannot be validated with mounted check.',
    correctionMessage:
        'Use instance methods, pass mounted state, or use a navigator key.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      // Only check static methods
      if (!node.isStatic) return;

      // Check parameters for BuildContext
      for (final param in node.parameters?.parameters ?? <FormalParameter>[]) {
        if (_isBuildContextParam(param)) {
          reporter.atNode(param, code);
        }
      }
    });
  }

  bool _isBuildContextParam(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      final typeSource = param.type?.toSource();
      if (typeSource == null) return false;
      // Check for BuildContext or BuildContext? (nullable)
      return typeSource == 'BuildContext' ||
          typeSource == 'BuildContext?' ||
          typeSource.contains('BuildContext');
    }
    if (param is DefaultFormalParameter) {
      return _isBuildContextParam(param.parameter);
    }
    return false;
  }
}

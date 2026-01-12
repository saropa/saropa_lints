// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// BuildContext safety rules for Flutter applications.
///
/// These rules detect common misuses of BuildContext that can lead to
/// runtime crashes, memory leaks, or unpredictable behavior.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
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
  void visitIfStatement(IfStatement node) {
    // Check if this is a positive context.mounted guard
    // If so, skip the entire then-branch (it's guarded)
    if (_isPositiveMountedGuard(node)) {
      // Only visit the else branch if it exists (not guarded)
      node.elseStatement?.accept(this);
      return;
    }

    // Check if this is a negated mounted guard with early return
    // The statements after the if are guarded, but we handle that at the
    // block level, so just continue normal traversal
    super.visitIfStatement(node);
  }

  /// Checks if statement is a positive mounted guard: `if (mounted)` or
  /// `if (context.mounted)` without negation.
  bool _isPositiveMountedGuard(IfStatement node) {
    final condition = node.expression.toSource();
    if (!condition.contains('mounted')) return false;

    // Make sure it's NOT negated
    final isNegated = condition.contains('!mounted') ||
        condition.contains('!this.mounted') ||
        condition.contains('!context.mounted') ||
        condition.contains('mounted == false') ||
        condition.contains('mounted==false');

    return !isNegated;
  }

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

// =============================================================================
// STATIC METHOD CONTEXT RULES (3 tiers)
// =============================================================================
//
// These rules address BuildContext usage in static methods at different
// strictness levels:
//
// 1. avoid_context_after_await_in_static (Essential/ERROR)
//    - Flags context used AFTER await in async static method
//    - This is the truly dangerous case - context may be invalid
//
// 2. avoid_context_in_async_static (Recommended/WARNING)
//    - Flags any async static method with BuildContext parameter
//    - Even if context is used before await, pattern is risky
//
// 3. avoid_context_in_static_methods (Comprehensive/INFO)
//    - Flags any static method with BuildContext parameter
//    - Sync methods are generally safe but pattern is discouraged

/// Warns when BuildContext is used after await in async static methods.
///
/// Alias: context_after_await_static, async_static_context_danger
///
/// This is the most dangerous pattern: after an await, the widget may have
/// been disposed, making the context invalid. Using it will crash the app.
///
/// See also:
/// - [AvoidContextInAsyncStaticRule] for any async static with context
/// - [AvoidContextInStaticMethodsRule] for any static with context
///
/// **BAD - Context used after await (CRASH RISK!):**
/// ```dart
/// class MyHelper {
///   static Future<void> fetchAndShow(BuildContext context) async {
///     final data = await fetchData();  // Widget may dispose during await
///     ScaffoldMessenger.of(context).showSnackBar(...);  // CRASH!
///   }
/// }
/// ```
///
/// **GOOD - Check mounted or use callback:**
/// ```dart
/// // Option 1: Pass mounted check callback
/// static Future<void> fetchAndShow(
///   BuildContext context,
///   bool Function() isMounted,
/// ) async {
///   final data = await fetchData();
///   if (!isMounted()) return;
///   ScaffoldMessenger.of(context).showSnackBar(...);
/// }
///
/// // Option 2: Use navigator key (no context needed)
/// static Future<void> fetchAndShow() async {
///   final data = await fetchData();
///   navigatorKey.currentState?.showSnackBar(...);
/// }
/// ```
class AvoidContextAfterAwaitInStaticRule extends SaropaLintRule {
  const AvoidContextAfterAwaitInStaticRule() : super(code: _code);

  /// Critical issue - causes crashes.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_context_after_await_in_static',
    problemMessage:
        'BuildContext used after await in static method. Context may be '
        'invalid after async gap.',
    correctionMessage:
        'Pass an isMounted callback, use a navigator key, or restructure '
        'to avoid context after await.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      // Only check async static methods
      if (!node.isStatic) return;
      if (node.body is! BlockFunctionBody) return;

      final body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      // Get BuildContext parameter names
      final contextParamNames = <String>[];
      for (final param in node.parameters?.parameters ?? <FormalParameter>[]) {
        final name = _getBuildContextParamName(param);
        if (name != null) contextParamNames.add(name);
      }
      if (contextParamNames.isEmpty) return;

      // Find await expressions and context usages after them
      final visitor = _ContextAfterAwaitVisitor(contextParamNames);
      body.block.accept(visitor);

      // Report each context usage after await
      for (final usage in visitor.contextUsagesAfterAwait) {
        reporter.atNode(usage, _code);
      }
    });
  }

  String? _getBuildContextParamName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      final typeSource = param.type?.toSource();
      if (typeSource == null) return null;
      if (typeSource == 'BuildContext' ||
          typeSource == 'BuildContext?' ||
          typeSource.contains('BuildContext')) {
        return param.name?.lexeme;
      }
    }
    if (param is DefaultFormalParameter) {
      return _getBuildContextParamName(param.parameter);
    }
    return null;
  }
}

/// Visitor to find context usages after await expressions.
class _ContextAfterAwaitVisitor extends RecursiveAstVisitor<void> {
  _ContextAfterAwaitVisitor(this.contextParamNames);

  final List<String> contextParamNames;
  final List<AstNode> contextUsagesAfterAwait = [];
  bool _seenAwait = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _seenAwait = true;
    super.visitAwaitExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_seenAwait && contextParamNames.contains(node.name)) {
      // Check if this is actually using the context (not just declaring)
      final parent = node.parent;
      if (parent is! FormalParameter && parent is! VariableDeclaration) {
        contextUsagesAfterAwait.add(node);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Don't descend into nested function expressions (callbacks)
    // They have their own async context
    return;
  }
}

/// Warns when BuildContext parameter is used in async static methods.
///
/// Alias: async_static_context, context_in_async_static
///
/// Async static methods with BuildContext are risky because the widget
/// may dispose during any async gap. Even if context is used before the
/// first await, the pattern encourages unsafe code additions later.
///
/// See also:
/// - [AvoidContextAfterAwaitInStaticRule] for the most dangerous case
/// - [AvoidContextInStaticMethodsRule] for sync static methods
///
/// **BAD - Async static with context:**
/// ```dart
/// class MyHelper {
///   static Future<void> showConfirmation(BuildContext context) async {
///     final confirmed = await showDialog(...);  // async gap
///     if (confirmed) Navigator.of(context).pop();  // risky!
///   }
/// }
/// ```
///
/// **GOOD - Pass mounted callback:**
/// ```dart
/// static Future<void> showConfirmation(
///   BuildContext context,
///   bool Function() isMounted,
/// ) async {
///   final confirmed = await showDialog(...);
///   if (!isMounted()) return;
///   Navigator.of(context).pop();
/// }
/// ```
///
/// **Quick fix available:** Adds `bool Function() isMounted` parameter.
class AvoidContextInAsyncStaticRule extends SaropaLintRule {
  const AvoidContextInAsyncStaticRule() : super(code: _code);

  /// Risky pattern that can lead to crashes.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_context_in_async_static',
    problemMessage:
        'BuildContext in async static method may become invalid during '
        'async operations.',
    correctionMessage:
        'Pass an isMounted callback, use a navigator key, or convert to '
        'instance method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      // Only check async static methods
      if (!node.isStatic) return;
      if (node.body is! BlockFunctionBody) return;

      final body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      // Check parameters for BuildContext
      for (final param in node.parameters?.parameters ?? <FormalParameter>[]) {
        if (_isBuildContextParam(param)) {
          reporter.atNode(param, _code);
        }
      }
    });
  }

  bool _isBuildContextParam(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      final typeSource = param.type?.toSource();
      if (typeSource == null) return false;
      return typeSource == 'BuildContext' ||
          typeSource == 'BuildContext?' ||
          typeSource.contains('BuildContext');
    }
    if (param is DefaultFormalParameter) {
      return _isBuildContextParam(param.parameter);
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddIsMountedCallbackFix()];
}

/// Quick fix that adds an isMounted callback parameter after BuildContext.
class _AddIsMountedCallbackFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (!node.isStatic) return;

      // Find the BuildContext parameter
      final params = node.parameters?.parameters ?? <FormalParameter>[];
      for (final param in params) {
        if (!param.sourceRange.intersects(analysisError.sourceRange)) continue;

        final changeBuilder = reporter.createChangeBuilder(
          message: 'Add isMounted callback parameter',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          // Insert after the BuildContext parameter
          builder.addSimpleInsertion(
            param.end,
            ', bool Function() isMounted',
          );
        });
        return;
      }
    });
  }
}

/// Warns when BuildContext is used in any static method.
///
/// Alias: static_context, context_in_static
///
/// Static methods don't have access to widget instance state, so they
/// can't check `mounted`. While synchronous static methods are generally
/// safe (context is used immediately), the pattern is discouraged as it
/// makes code harder to maintain and test.
///
/// See also:
/// - [AvoidContextAfterAwaitInStaticRule] for the most dangerous case
/// - [AvoidContextInAsyncStaticRule] for async static methods
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
/// // Option 2: Use extension method
/// extension ScaffoldMessengerExt on BuildContext {
///   void showError(String message) {
///     ScaffoldMessenger.of(this).showSnackBar(...);
///   }
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

  /// Discouraged pattern but generally safe for sync methods.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_context_in_static_methods',
    problemMessage:
        'BuildContext in static method. Consider instance method or '
        'extension instead.',
    correctionMessage:
        'Use instance methods, extension methods, or a navigator key.',
    errorSeverity: DiagnosticSeverity.INFO,
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

      // Skip async methods - handled by more specific rules
      if (node.body is BlockFunctionBody) {
        final body = node.body as BlockFunctionBody;
        if (body.isAsynchronous) return;
      }

      // Check parameters for BuildContext
      for (final param in node.parameters?.parameters ?? <FormalParameter>[]) {
        if (_isBuildContextParam(param)) {
          reporter.atNode(param, _code);
        }
      }
    });
  }

  bool _isBuildContextParam(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      final typeSource = param.type?.toSource();
      if (typeSource == null) return false;
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

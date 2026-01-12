// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// BuildContext safety rules for Flutter applications.
///
/// These rules detect common misuses of BuildContext that can lead to
/// runtime crashes, memory leaks, or unpredictable behavior.
///
/// See also: [async_context_utils.dart] for shared mounted-check utilities.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../async_context_utils.dart';
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

/// Warns when BuildContext is used after an await without a mounted check.
///
/// Alias: context_after_await, async_context, stale_context,
///        avoid_using_context_after_dispose
///
/// ## Why This Matters
///
/// After an `await`, the widget may have been unmounted (disposed). If you use
/// `context` without checking `mounted`, you risk:
/// - **Crashes**: `Looking up a deactivated widget's ancestor` exceptions
/// - **Memory leaks**: Keeping references to disposed widgets
/// - **Undefined behavior**: Actions on non-existent UI elements
///
/// ## Detection Patterns
///
/// This rule tracks await expressions and mounted guards at the block level:
/// - Resets protection after each `await` (new async gap = new risk)
/// - Recognizes `if (!mounted) return;` as protection for subsequent code
/// - Recognizes `if (mounted) { ... }` as protection for code inside the block
/// - Skips nested callbacks (they have their own valid context scope)
///
/// ## Recognized Mounted Guards
///
/// ```dart
/// if (!mounted) return;           // Early exit guard
/// if (!context.mounted) return;   // Flutter 3.7+ style
/// if (mounted == false) return;   // Explicit comparison
/// if (mounted) { ... }            // Positive block guard
/// ```
///
/// **BAD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   Navigator.of(context).push(...); // LINT: Context may be invalid!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (!mounted) return;  // Guard against disposed widget
///   Navigator.of(context).push(...);
/// }
/// ```
///
/// **ALSO GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (mounted) {
///     Navigator.of(context).push(...);  // Safe inside mounted block
///   }
/// }
/// ```
///
/// See also:
/// - [use_setstate_synchronously] - Similar rule for setState calls
/// - [avoid_scaffold_messenger_after_await] - Similar rule for ScaffoldMessenger
class AvoidContextAcrossAsyncRule extends SaropaLintRule {
  const AvoidContextAcrossAsyncRule() : super(code: _code);

  /// Context after await can crash when widget is disposed.
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
    // Check async method declarations
    context.registry.addMethodDeclaration((node) {
      if (node.body is! BlockFunctionBody) return;
      final body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      _checkAsyncBody(body.block, reporter);
    });

    // Check async function expressions (lambdas, callbacks)
    context.registry.addFunctionExpression((node) {
      if (node.body is! BlockFunctionBody) return;
      final body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      _checkAsyncBody(body.block, reporter);
    });
  }

  /// Analyzes async block for context usage after await without guards.
  ///
  /// Algorithm:
  /// 1. Track when we've seen an await (starts the "danger zone")
  /// 2. Reset guard flag after each await (need fresh guard per async gap)
  /// 3. Detect mounted guards that protect subsequent code
  /// 4. Report unguarded context usage after await
  void _checkAsyncBody(Block block, SaropaDiagnosticReporter reporter) {
    bool seenAwait = false;
    bool hasGuard = false;

    for (final statement in block.statements) {
      // Await found: enter danger zone, reset any previous guard
      if (containsAwait(statement)) {
        seenAwait = true;
        hasGuard = false;
        // Context in same statement as await is OK (e.g., `await foo(context)`)
        continue;
      }

      // Early-exit guard: `if (!mounted) return;` protects all code after
      if (seenAwait && isNegatedMountedGuard(statement)) {
        hasGuard = true;
        continue;
      }

      // Positive guard: `if (mounted) { ... }` - code inside is safe
      // But else-branch and code after are NOT protected
      if (seenAwait && isPositiveMountedGuard(statement)) {
        final ifStmt = statement as IfStatement;
        // Report context in else-branch (not protected)
        if (ifStmt.elseStatement != null) {
          _reportContextUsage(ifStmt.elseStatement!, reporter);
        }
        continue;
      }

      // In danger zone without guard: report any context usage
      if (seenAwait && !hasGuard) {
        _reportContextUsage(statement, reporter);
      }
    }
  }

  /// Finds and reports all context usages in the given statement.
  void _reportContextUsage(Statement stmt, SaropaDiagnosticReporter reporter) {
    stmt.visitChildren(
      ContextUsageFinder(onContextFound: (node) => reporter.atNode(node, code)),
    );
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddMountedGuardFix()];
}

/// Quick fix that inserts `if (!mounted) return;` before context usage.
class _AddMountedGuardFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleIdentifier((node) {
      if (node.name != 'context') return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the containing statement to insert guard before
      final statement = _findContainingStatement(node);
      if (statement == null) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add mounted guard before this statement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Calculate indentation from original statement
        final lineStart = resolver.lineInfo.getOffsetOfLine(
          resolver.lineInfo.getLocation(statement.offset).lineNumber - 1,
        );
        final leadingText = resolver.source.contents.data.substring(
          lineStart,
          statement.offset,
        );
        // Extract whitespace only (the indentation)
        final indent = leadingText.replaceAll(RegExp(r'[^\s]'), '');

        // Insert guard before the statement
        builder.addSimpleInsertion(
          statement.offset,
          'if (!mounted) return;\n$indent',
        );
      });
    });
  }

  /// Walks up the AST to find the statement containing the node.
  AstNode? _findContainingStatement(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is ExpressionStatement || current is ReturnStatement) {
        return current;
      }
      current = current.parent;
    }
    return null;
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

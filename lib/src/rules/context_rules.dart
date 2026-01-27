// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// BuildContext safety rules for Flutter applications.
///
/// These rules detect common misuses of BuildContext that can lead to
/// runtime crashes, memory leaks, or unpredictable behavior.
///
/// See also: `async_context_utils.dart` for shared mounted-check utilities.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_storing_context',
    problemMessage:
        '[avoid_storing_context] Storing a BuildContext in a field or variable for later use is dangerous because the context may become invalid after the widget is disposed or rebuilt. Using a stale context can cause exceptions, show dialogs on the wrong screen, or trigger subtle bugs. This is a common source of crashes and hard-to-diagnose UI issues in Flutter apps.',
    correctionMessage:
        'Always use BuildContext directly where needed, and avoid storing it in fields or long-lived variables. If you must use context asynchronously, check if the widget is still mounted before using it. Audit your codebase for stored BuildContext references and refactor to use context safely.',
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
      // Function types with BuildContext parameters are fine - they declare
      // callback signatures, not store actual context instances.
      // e.g., `Widget Function({required BuildContext context})` is safe.
      // Check the AST node type directly rather than relying on toSource()
      // string matching, which can fail for named-parameter function types.
      if (node.fields.type is GenericFunctionType) return;

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
    // Function types with BuildContext parameters are fine - they declare
    // callback signatures, not store actual context instances
    // e.g., `void Function(BuildContext context)` is safe
    if (type.contains('Function')) {
      return false;
    }

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
/// Alias: async_context, stale_context,
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
/// - `use_setstate_synchronously` - Similar rule for setState calls
/// - `avoid_scaffold_messenger_after_await` - Similar rule for ScaffoldMessenger
class AvoidContextAcrossAsyncRule extends SaropaLintRule {
  const AvoidContextAcrossAsyncRule() : super(code: _code);

  /// Context after await can crash when widget is disposed.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: require_build_context_scope (deprecated, use avoid_context_across_async)
  @override
  List<String> get configAliases =>
      const <String>['require_build_context_scope'];

  static const LintCode _code = LintCode(
    name: 'avoid_context_across_async',
    problemMessage:
        '[avoid_context_across_async] BuildContext used after await crashes '
        'if widget was disposed during the async gap. Check mounted first.',
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
  /// 5. Recurse into try-catch sub-blocks with proper state propagation
  void _checkAsyncBody(
    Block block,
    SaropaDiagnosticReporter reporter, {
    bool initialSeenAwait = false,
    bool initialHasGuard = false,
  }) {
    bool seenAwait = initialSeenAwait;
    bool hasGuard = initialHasGuard;

    for (final statement in block.statements) {
      // Try-catch: recurse into sub-blocks with proper await tracking
      if (statement is TryStatement) {
        if (_checkTryBody(statement, reporter,
            seenAwait: seenAwait, hasGuard: hasGuard)) {
          seenAwait = true;
          hasGuard = false;
        }
        continue;
      }

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

  /// Analyzes try-catch for context usage after await.
  ///
  /// Recurses into the try body with inherited await/guard state, then
  /// analyzes catch and finally blocks as danger zones (if any await was
  /// seen). Guards inside the try body do not protect catch/finally blocks
  /// because exceptions may be thrown before the guard executes.
  ///
  /// Returns true if the try body contains await expressions.
  bool _checkTryBody(
    TryStatement statement,
    SaropaDiagnosticReporter reporter, {
    bool seenAwait = false,
    bool hasGuard = false,
  }) {
    final tryHasAwait = containsAwait(statement.body);

    _checkAsyncBody(statement.body, reporter,
        initialSeenAwait: seenAwait, initialHasGuard: hasGuard);

    final catchInDanger = seenAwait || tryHasAwait;
    if (catchInDanger) {
      for (final clause in statement.catchClauses) {
        _checkAsyncBody(clause.body, reporter, initialSeenAwait: true);
      }
      if (statement.finallyBlock != null) {
        _checkAsyncBody(statement.finallyBlock!, reporter,
            initialSeenAwait: true);
      }
    }

    return tryHasAwait;
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
  // Cached regex for performance - matches any non-whitespace
  static final RegExp _nonWhitespacePattern = RegExp(r'[^\s]');

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
        final indent = leadingText.replaceAll(_nonWhitespacePattern, '');

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
/// ## Recognized Mounted Guards
///
/// The rule recognizes `context.mounted` guards and won't report false positives
/// when context is properly guarded:
///
/// ```dart
/// if (!context.mounted) return;        // Early exit guard
/// if (context.mounted == false) return; // Explicit comparison
/// if (context.mounted) { ... }          // Positive block guard
/// if (context.mounted && other) { ... } // Compound conditions
/// context.mounted ? context : null      // Guarded ternary
/// ```
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
/// **GOOD - Check mounted before using context:**
/// ```dart
/// static Future<void> fetchAndShow(BuildContext context) async {
///   final data = await fetchData();
///   if (!context.mounted) return;  // Guard protects subsequent code
///   ScaffoldMessenger.of(context).showSnackBar(...);  // Safe!
/// }
/// ```
///
/// **ALSO GOOD - Use callback or navigator key:**
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_context_after_await_in_static',
    problemMessage:
        '[avoid_context_after_await_in_static] BuildContext used after await in static method. Context may be '
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
        final name = getBuildContextParamName(param);
        if (name != null) contextParamNames.add(name);
      }
      if (contextParamNames.isEmpty) return;

      // Analyze block for context usages after await without guards
      _checkAsyncStaticBody(
        body.block,
        contextParamNames,
        (node) => reporter.atNode(node, _code),
      );
    });
  }

  /// Analyzes async static method body for context usage after await.
  ///
  /// Similar to [AvoidContextAcrossAsyncRule._checkAsyncBody] but tracks
  /// context parameter names instead of just 'context', and recognizes
  /// `context.mounted` guards in static methods.
  static void _checkAsyncStaticBody(
    Block block,
    List<String> contextParamNames,
    void Function(AstNode) onUnguardedUsage, {
    bool initialSeenAwait = false,
    bool initialHasGuard = false,
  }) {
    bool seenAwait = initialSeenAwait;
    bool hasGuard = initialHasGuard;

    for (final statement in block.statements) {
      // Try-catch: recurse into sub-blocks with proper await tracking
      if (statement is TryStatement) {
        if (_checkTryStaticBody(
          statement,
          contextParamNames,
          onUnguardedUsage,
          seenAwait: seenAwait,
          hasGuard: hasGuard,
        )) {
          seenAwait = true;
          hasGuard = false;
        }
        continue;
      }

      // Await found: enter danger zone, reset any previous guard
      if (containsAwait(statement)) {
        seenAwait = true;
        hasGuard = false;
        // Context in same statement as await is OK (e.g., `await foo(context)`)
        continue;
      }

      // Early-exit guard: `if (!context.mounted) return;` protects all code after
      if (seenAwait && _isContextMountedGuard(statement, contextParamNames)) {
        hasGuard = true;
        continue;
      }

      // Positive guard: `if (context.mounted) { ... }` - code inside is safe
      // But code after the if-statement is NOT protected
      if (seenAwait &&
          _isPositiveContextMountedGuard(statement, contextParamNames)) {
        final ifStmt = statement as IfStatement;
        // Report context in else-branch (not protected)
        if (ifStmt.elseStatement != null) {
          _reportContextUsageInStatic(
            ifStmt.elseStatement!,
            contextParamNames,
            onUnguardedUsage,
          );
        }
        continue;
      }

      // In danger zone without guard: report any context usage
      if (seenAwait && !hasGuard) {
        _reportContextUsageInStatic(
          statement,
          contextParamNames,
          onUnguardedUsage,
        );
      }
    }
  }

  /// Analyzes try-catch for context usage after await in static methods.
  ///
  /// Recurses into the try body with inherited await/guard state, then
  /// analyzes catch and finally blocks as danger zones (if any await was
  /// seen). Guards inside the try body do not protect catch/finally blocks
  /// because exceptions may be thrown before the guard executes.
  ///
  /// Returns true if the try body contains any await expressions.
  static bool _checkTryStaticBody(
    TryStatement statement,
    List<String> contextParamNames,
    void Function(AstNode) onUnguardedUsage, {
    bool seenAwait = false,
    bool hasGuard = false,
  }) {
    final tryHasAwait = containsAwait(statement.body);

    // Analyze try body with inherited state
    _checkAsyncStaticBody(
      statement.body,
      contextParamNames,
      onUnguardedUsage,
      initialSeenAwait: seenAwait,
      initialHasGuard: hasGuard,
    );

    // Catch/finally: danger zone if any prior await was seen
    final catchInDanger = seenAwait || tryHasAwait;
    if (catchInDanger) {
      for (final clause in statement.catchClauses) {
        _checkAsyncStaticBody(
          clause.body,
          contextParamNames,
          onUnguardedUsage,
          initialSeenAwait: true,
        );
      }
      if (statement.finallyBlock != null) {
        _checkAsyncStaticBody(
          statement.finallyBlock!,
          contextParamNames,
          onUnguardedUsage,
          initialSeenAwait: true,
        );
      }
    }

    return tryHasAwait;
  }

  /// Checks if statement is `if (!context.mounted) return;` for static methods.
  static bool _isContextMountedGuard(
    Statement stmt,
    List<String> contextParamNames,
  ) {
    if (stmt is! IfStatement) return false;

    // Must be a negated context.mounted check
    if (!_checksNotContextMounted(stmt.expression, contextParamNames)) {
      return false;
    }

    // Then branch must contain early exit (return or throw)
    return containsEarlyExit(stmt.thenStatement);
  }

  /// Checks if statement is `if (context.mounted) { ... }` for static methods.
  static bool _isPositiveContextMountedGuard(
    Statement stmt,
    List<String> contextParamNames,
  ) {
    if (stmt is! IfStatement) return false;
    return _checksContextMounted(stmt.expression, contextParamNames);
  }

  /// Checks if expression is `context.mounted` where context is a param name.
  static bool _checksContextMounted(
    Expression expr,
    List<String> contextParamNames,
  ) {
    // context.mounted
    if (expr is PrefixedIdentifier &&
        expr.identifier.name == 'mounted' &&
        contextParamNames.contains(expr.prefix.name)) {
      return true;
    }

    // context.mounted == true or true == context.mounted
    if (expr is BinaryExpression && expr.operator.type == TokenType.EQ_EQ) {
      final left = expr.leftOperand;
      final right = expr.rightOperand;
      if (left is BooleanLiteral && left.value == true) {
        return _checksContextMounted(right, contextParamNames);
      }
      if (right is BooleanLiteral && right.value == true) {
        return _checksContextMounted(left, contextParamNames);
      }
    }

    // Compound && conditions
    if (expr is BinaryExpression &&
        expr.operator.type == TokenType.AMPERSAND_AMPERSAND) {
      return _checksContextMounted(expr.leftOperand, contextParamNames) ||
          _checksContextMounted(expr.rightOperand, contextParamNames);
    }

    return false;
  }

  /// Checks if expression is `!context.mounted` where context is a param name.
  static bool _checksNotContextMounted(
    Expression expr,
    List<String> contextParamNames,
  ) {
    // !context.mounted
    if (expr is PrefixExpression && expr.operator.type == TokenType.BANG) {
      return _checksContextMounted(expr.operand, contextParamNames);
    }

    // context.mounted == false or false == context.mounted
    if (expr is BinaryExpression && expr.operator.type == TokenType.EQ_EQ) {
      final left = expr.leftOperand;
      final right = expr.rightOperand;
      if (left is BooleanLiteral && left.value == false) {
        return _checksContextMounted(right, contextParamNames);
      }
      if (right is BooleanLiteral && right.value == false) {
        return _checksContextMounted(left, contextParamNames);
      }
    }

    return false;
  }

  /// Reports context usage in a statement for static methods.
  static void _reportContextUsageInStatic(
    Statement stmt,
    List<String> contextParamNames,
    void Function(AstNode) onUnguardedUsage,
  ) {
    stmt.visitChildren(
      _StaticContextUsageFinder(
        contextParamNames: contextParamNames,
        onContextFound: onUnguardedUsage,
      ),
    );
  }
}

/// Visitor that finds context usage in static methods by parameter name.
///
/// Similar to [ContextUsageFinder] but tracks named context parameters
/// instead of just the literal 'context' identifier. Also checks for
/// ancestor mounted guards using `context.mounted`.
class _StaticContextUsageFinder extends RecursiveAstVisitor<void> {
  _StaticContextUsageFinder({
    required this.contextParamNames,
    required this.onContextFound,
  });

  final List<String> contextParamNames;
  final void Function(AstNode) onContextFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (contextParamNames.contains(node.name)) {
      // Skip if this is a parameter declaration or variable declaration
      final parent = node.parent;
      if (parent is FormalParameter || parent is VariableDeclaration) {
        super.visitSimpleIdentifier(node);
        return;
      }

      // Skip if this is a named argument label (e.g., `foo(context: value)`)
      if (parent is Label) {
        super.visitSimpleIdentifier(node);
        return;
      }

      // Safe: context.mounted check (context is receiver of .mounted)
      if (parent is PrefixedIdentifier && parent.identifier.name == 'mounted') {
        super.visitSimpleIdentifier(node);
        return;
      }

      // Safe: context in then-branch of `context.mounted ? context : ...`
      if (_isInMountedGuardedTernary(node)) {
        super.visitSimpleIdentifier(node);
        return;
      }

      // Safe: inside a mounted guard: if (context.mounted) { ... }
      if (_hasAncestorContextMountedCheck(node)) {
        super.visitSimpleIdentifier(node);
        return;
      }

      onContextFound(node);
    }
    super.visitSimpleIdentifier(node);
  }

  /// Checks if node has an ancestor if-statement with context.mounted check.
  bool _hasAncestorContextMountedCheck(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        if (AvoidContextAfterAwaitInStaticRule._checksContextMounted(
          current.expression,
          contextParamNames,
        )) {
          // Verify node is in THEN branch (protected), not ELSE branch
          if (_isInThenBranch(node, current)) return true;
        }
      }
      // Stop at function boundaries
      if (current is FunctionExpression || current is MethodDeclaration) break;
      current = current.parent;
    }
    return false;
  }

  /// Checks if node is in the then-branch of an if-statement.
  bool _isInThenBranch(AstNode node, IfStatement ifStmt) {
    AstNode? current = node;
    while (current != null && current != ifStmt) {
      if (current == ifStmt.thenStatement) return true;
      if (current == ifStmt.elseStatement) return false;
      current = current.parent;
    }
    return false;
  }

  /// Checks if node is in the then-branch of a mounted-guarded ternary.
  bool _isInMountedGuardedTernary(SimpleIdentifier node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ConditionalExpression) {
        // Check if this node is in the then-expression
        if (_isDescendantOf(node, current.thenExpression)) {
          // Check if condition is a mounted check
          if (_isMountedCheck(current.condition)) {
            return true;
          }
        }
        return false;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if expression is context.mounted or mounted.
  bool _isMountedCheck(Expression expr) {
    if (expr is PrefixedIdentifier && expr.identifier.name == 'mounted') {
      return contextParamNames.contains(expr.prefix.name);
    }
    if (expr is SimpleIdentifier && expr.name == 'mounted') {
      return true;
    }
    return false;
  }

  /// Checks if child is a descendant of parent.
  bool _isDescendantOf(AstNode child, AstNode parent) {
    AstNode? current = child;
    while (current != null) {
      if (current == parent) return true;
      current = current.parent;
    }
    return false;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Don't descend into callbacks - they have their own valid context scope
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_context_in_async_static',
    problemMessage:
        '[avoid_context_in_async_static] BuildContext in async static method may become invalid during '
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
        if (isBuildContextParam(param)) {
          reporter.atNode(param, _code);
        }
      }
    });
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_context_in_static_methods',
    problemMessage:
        '[avoid_context_in_static_methods] BuildContext in static method. Consider instance method or '
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
        if (isBuildContextParam(param)) {
          reporter.atNode(param, _code);
        }
      }
    });
  }
}

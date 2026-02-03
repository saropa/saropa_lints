// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../mode_constants_utils.dart';
import '../saropa_lint_rule.dart';

/// Test-only rule that always reports a lint at the start of the file.
///
/// Formerly: `always_fail_test_case`
class AlwaysFailRule extends SaropaLintRule {
  const AlwaysFailRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<String> get configAliases => const <String>['always_fail_test_case'];

  static const LintCode _code = LintCode(
    name: 'prefer_fail_test_case',
    problemMessage:
        '[prefer_fail_test_case] This custom lint always fails (test hook).',
    correctionMessage:
        'This rule always fails by design — it verifies your lint pipeline is active. Seeing this error confirms saropa_lints is running. Remove prefer_fail_test_case from your enabled rules once verified.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Token firstToken = unit.beginToken;
      reporter.atToken(firstToken, code);
    });
  }
}

// NOTE: AvoidCommentedOutCodeRule moved to stylistic_rules.dart (v4.2.0)
// The rule now reports at actual comment locations and has a quick fix.

/// Warns when debugPrint is used.
///
/// debugPrint should not be used in production code. Use a proper logging
/// solution instead that can be configured per environment.
///
/// Example of **bad** code:
/// ```dart
/// debugPrint('User logged in: $userId');
/// ```
///
/// Example of **good** code:
/// ```dart
/// logger.info('User logged in: $userId');
/// ```
///
/// **Quick fix available:** Comments out the debugPrint statement.
class AvoidDebugPrintRule extends SaropaLintRule {
  const AvoidDebugPrintRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_debug_print',
    problemMessage:
        '[avoid_debug_print] debugPrint bypasses structured logging, making it impossible to filter, search, or disable output per environment. '
        'Debug statements left in production code expose internal state to device logs, degrade performance through I/O overhead, and create noise that obscures real issues during troubleshooting.',
    correctionMessage:
        'Replace debugPrint with a structured logging package (e.g., logger, logging, or a custom Logger class) that supports log levels, filtering, and environment-aware output. '
        'This ensures debug output is suppressed in production while remaining available during development.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'debugPrint') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutDebugPrintFix()];
}

class _CommentOutDebugPrintFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'debugPrint') return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the statement containing this invocation
      final AstNode? statement = _findContainingStatement(node);
      if (statement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out debugPrint statement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Comment out the statement to preserve developer intent history
        final String originalCode = statement.toSource();
        builder.addSimpleReplacement(
          SourceRange(statement.offset, statement.length),
          '// $originalCode',
        );
      });
    });
  }

  AstNode? _findContainingStatement(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is ExpressionStatement) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }
}

/// Warns when `debugPrint()` calls are not guarded by a debug check.
///
/// The project's `debug()` function is production-safe logging infrastructure
/// with its own level filtering and Crashlytics routing — it is NOT flagged.
///
/// `debugPrint()` bypasses all of that and writes directly to the console,
/// so it should be guarded to avoid cluttering production output.
///
/// **Guarded patterns (allowed):**
/// - Inside `if (kDebugMode)` block
/// - Inside `if (DebugType.*.isDebug)` block
/// - Inside `if (MainSettings.isDebugMode)` block
/// - Inside `if (isDebug*)` local variable check
/// - Inside exception handler (catch block)
/// - Inside assert() statement
/// - Inside a method/function named `debug*` or `_debug*` (debug helpers)
///
/// Example of **bad** code:
/// ```dart
/// void someMethod() {
///   debugPrint('Value: $x');  // Unguarded - will print in production
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void someMethod() {
///   if (kDebugMode) {
///     debugPrint('Value: $x');
///   }
///
///   // debug() is always allowed — it's production-safe
///   debug('Missing data');
///   debug('Important warning', level: DebugLevels.Warning);
/// }
/// ```
class AvoidUnguardedDebugRule extends SaropaLintRule {
  const AvoidUnguardedDebugRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_unguarded_debug',
    problemMessage:
        '[avoid_unguarded_debug] debugPrint() is not guarded by a debug mode check.',
    correctionMessage: 'Wrap in if (kDebugMode) or if (DebugType.*.isDebug). '
        'Consider using debug() instead, which is production-safe.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Pre-compiled patterns for performance - avoid creating RegExp in loops
  static final RegExp _isDebugPattern = RegExp(r'\bisDebug\w*\b');
  static final RegExp _debugSuffixPattern = RegExp(r'\bis\w*Debug\b');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only flag debugPrint() — the project's debug() function is
    // production-safe logging infrastructure with its own level filtering.
    // Bare debug() calls are intentional and should not require guards.

    // Check for debugPrint() function calls
    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final Expression function = node.function;
      if (function is SimpleIdentifier && function.name == 'debugPrint') {
        if (!_isGuarded(node)) {
          reporter.atNode(node, code);
        }
      }
    });

    // Check for debugPrint() method invocations
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'debugPrint') {
        if (!_isGuarded(node)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  /// Check if the node is inside a debug guard
  bool _isGuarded(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      // Check for if statement guards
      if (current is IfStatement) {
        if (_isDebugGuardCondition(current.expression)) {
          return true;
        }
      }

      // Check for enclosing method/function named debug* or _debug*
      // These are debug helper methods that are only called from guarded sites
      if (current is MethodDeclaration) {
        final String name = current.name.lexeme;
        if (name.startsWith('debug') || name.startsWith('_debug')) {
          return true;
        }
      }
      if (current is FunctionDeclaration) {
        final String name = current.name.lexeme;
        if (name.startsWith('debug') || name.startsWith('_debug')) {
          return true;
        }
      }

      // Check for assert statement (debug code by definition)
      if (current is AssertStatement) {
        return true;
      }

      // Check for catch clause (exception handling is allowed)
      if (current is CatchClause) {
        return true;
      }

      // Check for try statement's catch blocks
      if (current is TryStatement) {
        // If we're in a catch block, it's allowed
        for (final CatchClause catchClause in current.catchClauses) {
          if (_isDescendantOf(node, catchClause)) {
            return true;
          }
        }
      }

      current = current.parent;
    }

    return false;
  }

  /// Check if a condition is a debug guard
  bool _isDebugGuardCondition(Expression condition) {
    final String source = condition.toSource();

    // kDebugMode
    if (source.contains('kDebugMode')) {
      return true;
    }

    // DebugType.*.isDebug
    if (source.contains('DebugType.') && source.contains('.isDebug')) {
      return true;
    }

    // MainSettings.isDebugMode or MainSettings.isProfileMode
    if (source.contains('MainSettings.isDebugMode') ||
        source.contains('MainSettings.isProfileMode')) {
      return true;
    }

    // isDebug* local variable patterns
    if (_isDebugPattern.hasMatch(source)) {
      return true;
    }

    // is*Debug patterns (isAudioDebug, isWidgetDebug, etc.)
    if (_debugSuffixPattern.hasMatch(source)) {
      return true;
    }

    // UserPreferenceType.Debug* patterns
    if (source.contains('UserPreferenceType.Debug')) {
      return true;
    }

    return false;
  }

  /// Check if a node is a descendant of another node
  bool _isDescendantOf(AstNode node, AstNode potentialAncestor) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current == potentialAncestor) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when `// ignore:` comments don't have a preceding explanatory comment.
///
/// Analyzer ignore comments should be documented to explain why the rule is being
/// ignored. This helps future maintainers understand the reasoning.
///
/// Example of **bad** code:
/// ```dart
/// // ignore: avoid_print
/// print('Hello');
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Logging is needed here for debugging during development
/// // ignore: avoid_print
/// print('Hello');
/// ```
class PreferCommentingAnalyzerIgnoresRule extends SaropaLintRule {
  const PreferCommentingAnalyzerIgnoresRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_commenting_analyzer_ignores',
    problemMessage:
        '[prefer_commenting_analyzer_ignores] Analyzer ignore comment should have a preceding explanatory comment.',
    correctionMessage:
        'Add a comment on the line above explaining why this rule is ignored.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pre-compiled patterns for performance
  static final RegExp _ignorePattern = RegExp(r'^//\s*ignore:');
  static final RegExp _ignoreForFilePattern = RegExp(r'^//\s*ignore_for_file:');
  static final RegExp _ignoreDirectivePattern =
      RegExp(r'//\s*ignore(?:_for_file)?:\s*\S+');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final String content = resolver.source.contents.data;
      final List<String> lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i].trim();

        // Check for ignore comments (both // ignore: and // ignore_for_file:)
        if (_isIgnoreComment(line)) {
          // Check if there's a preceding explanatory comment
          if (!_hasPrecedingComment(lines, i)) {
            // Report at the ignore comment location
            final int columnStart = lines[i].indexOf('// ignore');
            if (columnStart >= 0) {
              // Find the actual offset in the file
              int offset = 0;
              for (int j = 0; j < i; j++) {
                offset += lines[j].length + 1; // +1 for newline
              }
              offset += columnStart;

              // Find the end of the ignore directive
              final int length = _getIgnoreCommentLength(lines[i], columnStart);

              reporter.atOffset(
                offset: offset,
                length: length,
                errorCode: code,
              );
            }
          }
        }
      }
    });
  }

  /// Check if a line contains an ignore comment
  bool _isIgnoreComment(String line) {
    // Match // ignore: or // ignore_for_file:
    // But not lines that are already explanatory comments followed by ignore
    return _ignorePattern.hasMatch(line) ||
        _ignoreForFilePattern.hasMatch(line);
  }

  /// Check if the line before has an explanatory comment
  bool _hasPrecedingComment(List<String> lines, int currentIndex) {
    if (currentIndex == 0) return false;

    // Look at the previous non-empty line
    for (int i = currentIndex - 1; i >= 0; i--) {
      final String prevLine = lines[i].trim();

      // Skip empty lines
      if (prevLine.isEmpty) continue;

      // Check if it's a comment (but not another ignore comment)
      if (prevLine.startsWith('//')) {
        // Make sure it's not another ignore comment
        if (!_isIgnoreComment(prevLine)) {
          return true;
        }
        // If it's another ignore, keep looking
        continue;
      }

      // If we hit code, there's no preceding comment
      return false;
    }

    return false;
  }

  /// Get the length of the ignore comment for reporting
  int _getIgnoreCommentLength(String line, int start) {
    // Find the ignore comment pattern directly in the full line
    final RegExpMatch? match = _ignoreDirectivePattern.firstMatch(line);
    if (match != null && match.start >= start) {
      return match.end - start;
    }
    return line.length - start;
  }
}

// =============================================================================
// Debug Output Rules
// =============================================================================

/// Suggests using debugPrint instead of print for better output throttling.
///
/// The print() function can overwhelm the system console and cause message
/// loss when called rapidly. debugPrint() throttles output to avoid this
/// issue and is the recommended way to log debug information.
///
/// **BAD:**
/// ```dart
/// for (final item in largeList) {
///   print('Processing: $item'); // Can overflow console buffer!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// for (final item in largeList) {
///   debugPrint('Processing: $item'); // Throttled output
/// }
/// ```
///
/// **Note:** In production code, consider using a proper logging framework
/// instead of either print() or debugPrint().
class PreferDebugPrintRule extends SaropaLintRule {
  const PreferDebugPrintRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_debugPrint',
    problemMessage:
        '[prefer_debugPrint] print() should use debugPrint() for throttled console output.',
    correctionMessage:
        'Replace print() with debugPrint() to prevent console buffer overflow.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Only check for print function calls
      if (node.methodName.name != 'print') return;

      // Make sure it's a top-level print call (no target)
      // This avoids matching object.print() methods
      if (node.target != null) return;

      // Skip if inside a test file - print is often acceptable there
      // (handled by testRelevance - default skips test files)

      reporter.atNode(node, code);
    });

    // Also check for function expression invocations of print
    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final Expression function = node.function;
      if (function is SimpleIdentifier && function.name == 'print') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceWithDebugPrintFix()];
}

class _ReplaceWithDebugPrintFix extends DartFix {
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
      if (node.methodName.name != 'print') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with debugPrint',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'debugPrint',
        );
      });
    });
  }
}

// =============================================================================
// v4.1.6 Rules - Logging Best Practices
// =============================================================================

/// Warns when print() is used without kDebugMode check.
///
/// print() statements execute in release builds, potentially exposing
/// sensitive information or impacting performance. Always guard print
/// statements with kDebugMode.
///
/// `[CONTEXT]` - Requires understanding surrounding code context.
///
/// **BAD:**
/// ```dart
/// void processUser(User user) {
///   print('Processing user: ${user.email}'); // Runs in release!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void processUser(User user) {
///   if (kDebugMode) {
///     print('Processing user: ${user.email}');
///   }
/// }
/// ```
class AvoidPrintInReleaseRule extends SaropaLintRule {
  const AvoidPrintInReleaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_print_in_release',
    problemMessage:
        '[avoid_print_in_release] Using print() in production exposes debug information to end users, can leak sensitive data, and negatively impacts performance. Print statements are not optimized for release builds and may clutter logs, making it harder to diagnose real issues. This can also violate privacy policies and app store guidelines.',
    correctionMessage:
        'Wrap print() calls in if (kDebugMode) or use a logging framework with configurable log levels. Remove or refactor print statements before release to ensure only intentional logging is present.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;
      if (node.target != null) return; // Skip object.print()

      if (!_isInsideDebugGuard(node)) {
        reporter.atNode(node, code);
      }
    });

    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final Expression function = node.function;
      if (function is SimpleIdentifier && function.name == 'print') {
        if (!_isInsideDebugGuard(node)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _isInsideDebugGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (usesFlutterModeConstants(condition)) {
          return true;
        }
      }
      if (current is AssertStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_WrapInDebugModeFix()];
}

class _WrapInDebugModeFix extends DartFix {
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
      if (node.methodName.name != 'print') return;

      final AstNode? statement = _findStatement(node);
      if (statement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap in if (kDebugMode)',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final String original = statement.toSource();
        builder.addSimpleReplacement(
          SourceRange(statement.offset, statement.length),
          'if (kDebugMode) {\n  $original\n}',
        );
      });
    });
  }

  AstNode? _findStatement(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is ExpressionStatement) return current;
      current = current.parent;
    }
    return null;
  }
}

/// Warns when log calls use string concatenation instead of structured logging.
///
/// String concatenation in log messages wastes CPU cycles constructing
/// strings even when logging is disabled. Use structured logging with
/// placeholders or log levels.
///
/// **BAD:**
/// ```dart
/// log('User ' + user.name + ' logged in at ' + timestamp.toString());
/// print('Error: ' + error.message + ' Stack: ' + stackTrace.toString());
/// ```
///
/// **GOOD:**
/// ```dart
/// log('User logged in', data: {'user': user.name, 'time': timestamp});
/// logger.error('Error occurred', error: error, stackTrace: stackTrace);
/// ```
class RequireStructuredLoggingRule extends SaropaLintRule {
  const RequireStructuredLoggingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_structured_logging',
    problemMessage:
        '[require_structured_logging] String concatenation in logs wastes CPU building strings even when logging is disabled.',
    correctionMessage:
        'Use structured logging with named parameters: log("event", data: {"key": value}).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _logMethods = {
    'log',
    'print',
    'debugPrint',
    'info',
    'warning',
    'error',
    'severe',
    'fine',
    'finer',
    'finest',
    'debug',
    'trace',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_logMethods.contains(methodName)) return;

      // Check if first argument uses string concatenation
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) return;

      if (_usesConcatenation(firstArg)) {
        reporter.atNode(firstArg, code);
      }
    });
  }

  bool _usesConcatenation(Expression expr) {
    if (expr is BinaryExpression && expr.operator.lexeme == '+') {
      // Check if either operand is a string
      if (expr.leftOperand is StringLiteral ||
          expr.rightOperand is StringLiteral) {
        return true;
      }
      // Recursively check for nested concatenation
      return _usesConcatenation(expr.leftOperand) ||
          _usesConcatenation(expr.rightOperand);
    }
    return false;
  }
}

/// Warns when sensitive data is logged.
///
/// Alias: avoid_sensitive_data_in_logs
///
/// `[HEURISTIC]` - Uses pattern matching to detect sensitive variable names.
///
/// Logging passwords, tokens, secrets, or other sensitive data is a security
/// risk that can expose credentials and violate compliance requirements
/// (OWASP A09: Security Logging and Monitoring Failures).
///
/// This rule uses AST-based detection to distinguish between:
/// - **Actual data exposure**: `$password`, `${user.token}` → FLAGGED
/// - **Safe descriptive text**: `'Updating token.'`, `'session expired'` → OK
/// - **Safe property access**: `${password.length}`, `${token != null}` → OK
///
/// **BAD:**
/// ```dart
/// print('Login attempt with password: $password');
/// log('Token: ${user.accessToken}');
/// debugPrint('API key: $apiKey, secret: $secretKey');
/// ```
///
/// **GOOD:**
/// ```dart
/// print('Login attempt for user: ${user.email}');
/// log('Token refreshed', data: {'userId': user.id});
/// debugPrint('API call completed');
/// // Safe: just descriptive text, no actual data
/// print('Updating local token.');
/// ```
///
/// **Quick fix available:** Comments out the sensitive log statement for review.
class AvoidSensitiveInLogsRule extends SaropaLintRule {
  const AvoidSensitiveInLogsRule() : super(code: _code);

  /// Config alias for backwards compatibility with avoid_sensitive_data_in_logs
  @override
  List<String> get configAliases =>
      const <String>['avoid_sensitive_data_in_logs'];

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  /// OWASP mapping: M6 (Privacy Controls), A09 (Logging Failures)
  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m6},
        web: <OwaspWeb>{OwaspWeb.a09},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_sensitive_in_logs',
    problemMessage:
        '[avoid_sensitive_in_logs] Logging sensitive data (such as passwords, tokens, or personal information) exposes users to credential theft, privacy violations, and compliance failures (e.g., OWASP A09). Attackers or support staff may access logs and extract secrets, leading to data breaches.',
    correctionMessage:
        'Never log sensitive information. Remove or redact secrets, credentials, and personal data before logging. Use secure logging practices and review log statements for accidental leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _logMethods = {
    'log',
    'print',
    'debugPrint',
    'info',
    'warning',
    'error',
    'severe',
    'debug',
    'trace',
  };

  // Note: Pattern excludes 'auth' alone as it's too broad (matches 'author',
  // 'authority'). Uses authToken, authKey, authCode instead.
  static final RegExp _sensitivePattern = RegExp(
    r'\b(password|passwd|pwd|secret|token|apiKey|api_key|accessToken|'
    r'access_token|refreshToken|refresh_token|privateKey|private_key|'
    r'secretKey|secret_key|credential|authToken|authKey|authCode|'
    r'bearer|jwt|session|cookie|ssn|creditCard|credit_card|cvv|pin|otp)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_logMethods.contains(methodName)) return;

      // Check all arguments for sensitive patterns
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (_containsSensitiveData(arg.expression)) {
            reporter.atNode(arg, code);
          }
        } else if (_containsSensitiveData(arg)) {
          reporter.atNode(arg, code);
        }
      }
    });
  }

  bool _containsSensitiveData(Expression expr) {
    // For simple string literals with no interpolation, no sensitive data
    // is actually being logged (just descriptive text like "updating token")
    // This MUST be checked first before StringInterpolation.
    if (expr is SimpleStringLiteral) {
      return false;
    }

    // For adjacent strings (multi-line string literals), check each part
    if (expr is AdjacentStrings) {
      for (final StringLiteral part in expr.strings) {
        if (_containsSensitiveData(part)) {
          return true;
        }
      }
      return false;
    }

    // Check string literals for interpolated sensitive variables
    if (expr is StringInterpolation) {
      for (final InterpolationElement element in expr.elements) {
        if (element is InterpolationExpression) {
          // Recursively check the interpolated expression
          if (_containsSensitiveData(element.expression)) {
            return true;
          }
        }
        // Plain string parts (InterpolationString) are ignored - they're just
        // descriptive text, not actual sensitive data being logged
      }
      return false;
    }

    // For concatenation, check if sensitive variables are being concatenated
    if (expr is BinaryExpression && expr.operator.lexeme == '+') {
      return _containsSensitiveData(expr.leftOperand) ||
          _containsSensitiveData(expr.rightOperand);
    }

    // For conditional expressions, check all branches
    if (expr is ConditionalExpression) {
      // Don't check the condition itself - only what gets logged
      return _containsSensitiveData(expr.thenExpression) ||
          _containsSensitiveData(expr.elseExpression);
    }

    // For parenthesized expressions, check inside
    if (expr is ParenthesizedExpression) {
      return _containsSensitiveData(expr.expression);
    }

    // For identifiers (variable references) - check if the name is sensitive
    if (expr is SimpleIdentifier) {
      return _sensitivePattern.hasMatch(expr.name);
    }

    // For property access (e.g., user.token) - check the property name
    if (expr is PrefixedIdentifier) {
      return _sensitivePattern.hasMatch(expr.identifier.name);
    }

    if (expr is PropertyAccess) {
      return _sensitivePattern.hasMatch(expr.propertyName.name);
    }

    // For method calls, don't flag - method results aren't inherently sensitive
    // by name (e.g., getToken() might return masked data)
    if (expr is MethodInvocation) {
      // But do check arguments being passed
      for (final Expression arg in expr.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (_containsSensitiveData(arg.expression)) {
            return true;
          }
        } else if (_containsSensitiveData(arg)) {
          return true;
        }
      }
      return false;
    }

    // For index expressions (e.g., map['token']), check the index
    if (expr is IndexExpression) {
      final Expression index = expr.index;
      if (index is SimpleStringLiteral) {
        return _sensitivePattern.hasMatch(index.value);
      }
      return false;
    }

    // For other expressions (literals, etc.), no sensitive data
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutSensitiveLogFix()];
}

class _CommentOutSensitiveLogFix extends DartFix {
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

      // Find the statement containing this method invocation
      AstNode? current = node;
      while (current != null && current is! Statement) {
        current = current.parent;
      }
      if (current == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out sensitive log statement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(current!.offset, current.length),
          '// SECURITY: ${current.toSource()}',
        );
      });
    });
  }
}

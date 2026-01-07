// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Test-only rule that always reports a lint at the start of the file.
class AlwaysFailRule extends SaropaLintRule {
  const AlwaysFailRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'always_fail',
    problemMessage: 'This custom lint always fails (test hook).',
    correctionMessage: 'Disable the rule or remove the test lint trigger.',
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

/// Warns when commented-out code is detected.
///
/// Commented-out code can clutter the codebase and make it harder to read.
/// It's usually better to delete unused code (it can be retrieved from version
/// control if needed).
class AvoidCommentedOutCodeRule extends SaropaLintRule {
  const AvoidCommentedOutCodeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_commented_out_code',
    problemMessage: 'Avoid commented-out code.',
    correctionMessage:
        'Remove commented-out code. Use version control to preserve history.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Common code patterns that indicate commented-out code
  static final RegExp _codePattern = RegExp(
    r'^\s*//\s*('
    r'(if|else|for|while|switch|case|return|break|continue|throw|try|catch|finally)\s*[\(\{]|'
    r'(var|final|const|int|double|String|bool|List|Map|Set|void|Future|Stream)\s+\w+|'
    r'\w+\s*[=<>!]+|'
    r'\w+\s*\([^)]*\)\s*[;{]|'
    r'\w+\.\w+\s*[\(;]|'
    r'@\w+|'
    r'import\s+|'
    r'class\s+\w+|'
    r'}\s*$|'
    r'{\s*$'
    r')',
    multiLine: true,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final String content = node.toSource();
      final List<String> lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        if (_codePattern.hasMatch(line)) {
          // This is a heuristic - we report at the compilation unit level
          // In practice, you'd want more sophisticated detection
          reporter.atOffset(
            offset: node.offset,
            length: 1,
            errorCode: code,
          );
          return; // Only report once per file
        }
      }
    });
  }
}

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

  static const LintCode _code = LintCode(
    name: 'avoid_debug_print',
    problemMessage: 'Avoid using debugPrint. '
        'Use a proper logging solution instead.',
    correctionMessage: 'Replace debugPrint with a logger that can be '
        'configured per environment.',
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

/// Warns when `debug()` or `debugPrint()` calls are not guarded by a debug check.
///
/// Unguarded debug statements can:
/// - Clutter production logs/databases
/// - Expose sensitive information
/// - Impact performance
///
/// **Guarded patterns (allowed):**
/// - Inside `if (kDebugMode)` block
/// - Inside `if (DebugType.*.isDebug)` block
/// - Inside `if (MainSettings.isDebugMode)` block
/// - Inside `if (isDebug*)` local variable check
/// - Has `level: DebugLevels.Warning/Error/Info/Todo` parameter
/// - Inside exception handler (catch block)
/// - Inside assert() statement
///
/// Example of **bad** code:
/// ```dart
/// void someMethod() {
///   debug('Processing item');  // Unguarded - will run in production
///   debugPrint('Value: $x');   // Unguarded
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
///   if (DebugType.Activity.isDebug) {
///     debug('Processing item');
///   }
///
///   debug('Important warning', level: DebugLevels.Warning);
/// }
/// ```
class AvoidUnguardedDebugRule extends SaropaLintRule {
  const AvoidUnguardedDebugRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unguarded_debug',
    problemMessage: 'Debug statement is not guarded by a debug mode check.',
    correctionMessage: 'Wrap in if (kDebugMode), if (DebugType.*.isDebug), '
        'or add level: DebugLevels.Warning/Error parameter.',
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
    // Check for debug() function calls
    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final Expression function = node.function;
      if (function is SimpleIdentifier && function.name == 'debug') {
        if (!_isGuarded(node) && !_hasDebugLevel(node.argumentList)) {
          reporter.atNode(node, code);
        }
      }
    });

    // Check for debug() and debugPrint() method invocations
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'debug' || methodName == 'debugPrint') {
        if (!_isGuarded(node) && !_hasDebugLevel(node.argumentList)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  /// Check if the debug call has a level parameter with Warning/Error/Info/Todo
  bool _hasDebugLevel(ArgumentList args) {
    for (final Expression arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'level') {
        final String source = arg.expression.toSource();
        if (source.contains('DebugLevels.Warning') ||
            source.contains('DebugLevels.Error') ||
            source.contains('DebugLevels.Info') ||
            source.contains('DebugLevels.Todo')) {
          return true;
        }
      }
    }
    return false;
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

  static const LintCode _code = LintCode(
    name: 'prefer_commenting_analyzer_ignores',
    problemMessage:
        'Analyzer ignore comment should have a preceding explanatory comment.',
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

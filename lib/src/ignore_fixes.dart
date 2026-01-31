// ignore_for_file: always_specify_types, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Generic quick fix that adds `// ignore: rule_name` comment above a violation.
///
/// This fix can be used by any lint rule to allow developers to suppress
/// a single occurrence with a comment like:
/// ```dart
/// // ignore: rule_name - [rationale here]
/// violatingCode();
/// ```
class AddIgnoreCommentFix extends DartFix {
  /// Creates a fix that adds an ignore comment for the given rule.
  AddIgnoreCommentFix(this.ruleName);

  /// The name of the rule to ignore.
  final String ruleName;

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    final changeBuilder = reporter.createChangeBuilder(
      message: "Ignore '$ruleName' for this line",
      priority: 1, // Low priority - rule-specific fixes should come first
    );

    changeBuilder.addDartFileEdit((builder) {
      // Get line info to find the start of the line
      final lineInfo = resolver.lineInfo;
      final errorLine = lineInfo.getLocation(analysisError.offset).lineNumber;
      final lineStart = lineInfo.getOffsetOfLine(errorLine - 1);

      // Get the indentation of the current line
      final content = resolver.source.contents.data;
      final indentation = _getLineIndentation(content, lineStart);

      // Insert ignore comment at the start of the line with matching indentation
      builder.addSimpleInsertion(
        lineStart,
        '$indentation// ignore: $ruleName\n',
      );
    });
  }

  /// Extracts the leading whitespace from a line starting at [lineStart].
  String _getLineIndentation(String content, int lineStart) {
    final buffer = StringBuffer();
    for (int i = lineStart; i < content.length; i++) {
      final char = content[i];
      if (char == ' ' || char == '\t') {
        buffer.write(char);
      } else {
        break;
      }
    }
    return buffer.toString();
  }
}

/// Generic quick fix that adds `// ignore_for_file: rule_name` at the top of file.
///
/// This fix can be used by any lint rule to allow developers to suppress
/// all occurrences of a rule in a file:
/// ```dart
/// // ignore_for_file: rule_name
///
/// // ... rest of file
/// ```
class AddIgnoreForFileFix extends DartFix {
  /// Creates a fix that adds an ignore_for_file comment for the given rule.
  AddIgnoreForFileFix(this.ruleName);

  /// The name of the rule to ignore.
  final String ruleName;

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    final changeBuilder = reporter.createChangeBuilder(
      message: "Ignore '$ruleName' for this file",
      priority: 0, // Lowest priority
    );

    changeBuilder.addDartFileEdit((builder) {
      final content = resolver.source.contents.data;

      // Find the insertion point (after any existing ignore_for_file comments
      // and library/part directives)
      final insertOffset = _findIgnoreForFileInsertOffset(content);

      // Check if this ignore_for_file already exists
      if (_hasIgnoreForFile(content, ruleName)) {
        return; // Already ignored, don't add duplicate
      }

      builder.addSimpleInsertion(
        insertOffset,
        '// ignore_for_file: $ruleName\n',
      );
    });
  }

  /// Finds the best offset to insert an ignore_for_file comment.
  ///
  /// Insertion priority:
  /// 1. After existing `// ignore_for_file:` comments (group them together)
  /// 2. After header comments (copyright, license) but before code
  /// 3. At position 0 if file has no header comments
  int _findIgnoreForFileInsertOffset(String content) {
    final lines = content.split('\n');
    int offset = 0;
    int lastIgnoreForFileEnd = 0;
    int lastHeaderCommentEnd = 0;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('// ignore_for_file:')) {
        // Track end of ignore_for_file comment block
        lastIgnoreForFileEnd = offset + line.length + 1;
      } else if (trimmed.startsWith('//') || trimmed.isEmpty) {
        // Track end of header comment block (including blank lines between)
        if (trimmed.startsWith('//')) {
          lastHeaderCommentEnd = offset + line.length + 1;
        }
      } else {
        // First non-comment, non-empty line - stop here
        break;
      }

      offset += line.length + 1;
    }

    // Priority: existing ignore_for_file > header comments > beginning
    if (lastIgnoreForFileEnd > 0) {
      return lastIgnoreForFileEnd;
    }
    if (lastHeaderCommentEnd > 0) {
      return lastHeaderCommentEnd;
    }
    return 0;
  }

  /// Checks if the file already has an ignore_for_file for this rule.
  bool _hasIgnoreForFile(String content, String ruleName) {
    final pattern = RegExp(
      r'//\s*ignore_for_file\s*:.*\b' + RegExp.escape(ruleName) + r'\b',
    );
    return pattern.hasMatch(content);
  }
}

/// Quick fix that wraps a method invocation's enclosing statement
/// in a try-catch block.
///
/// Used by rules that require error handling around operations
/// (database calls, PDF loading, location requests, etc.).
class WrapInTryCatchFix extends DartFix {
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

      final stmt = _findEnclosingStatement(node);
      if (stmt == null) return;

      final source = resolver.source.contents.data;
      final indent = _getStatementIndent(source, stmt.offset);
      final stmtSource = stmt.toSource();

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap in try-catch',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          stmt.sourceRange,
          'try {\n'
          '$indent  $stmtSource\n'
          '$indent} catch (e) {\n'
          '$indent  // TODO: Handle error\n'
          '$indent}',
        );
      });
    });
  }

  /// Walks up the AST to find the nearest enclosing statement.
  Statement? _findEnclosingStatement(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ExpressionStatement ||
          current is VariableDeclarationStatement ||
          current is ReturnStatement) {
        return current as Statement;
      }
      current = current.parent;
    }
    return null;
  }

  /// Returns the leading whitespace before the statement on its line.
  String _getStatementIndent(String source, int stmtOffset) {
    int lineStart = stmtOffset;
    while (lineStart > 0 && source[lineStart - 1] != '\n') {
      lineStart--;
    }
    return source.substring(lineStart, stmtOffset);
  }
}

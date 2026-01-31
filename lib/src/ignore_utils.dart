// ignore_for_file: always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';

/// Utilities for handling ignore comments with hyphen/underscore flexibility.
///
/// Dart lint rules conventionally use underscores (e.g., `avoid_print`),
/// but users sometimes write ignore comments with hyphens (e.g., `avoid-print`).
/// This utility allows rules to accept both formats.
///
/// ## Supported Comment Positions
///
/// This utility detects ignore comments in several positions:
///
/// ### Leading comments (above the node)
/// ```dart
/// // ignore: my_rule
/// doSomething();
/// ```
///
/// ### Trailing comments (same line)
/// ```dart
/// doSomething(); // ignore: my_rule
/// ```
///
/// ### Nested expressions (comment on parent)
/// ```dart
/// // ignore: no_empty_block
/// stream.listen((_) {});
/// ```
///
/// ### Constructor arguments
/// ```dart
/// WebsiteItem(
///   url: 'http://example.com', // ignore: require_https
///   label: 'Test',
/// );
/// ```
///
/// ### List/Map items
/// ```dart
/// final urls = [
///   'http://example.com', // ignore: require_https
///   'https://safe.com',
/// ];
/// ```
///
/// ### Chained method calls (mid-chain comments)
/// ```dart
/// position = await Geolocator
///     // ignore: require_android_permission_request
///     .getCurrentPosition();
/// ```
///
/// ## Implementation Notes
///
/// Trailing comments are stored as `precedingComments` on subsequent tokens,
/// not on the current token. This utility walks forward through tokens to find
/// trailing comments, using line information to ensure the comment is actually
/// on the same line as the target node.
class IgnoreUtils {
  IgnoreUtils._();

  /// Converts a rule name from underscore format to hyphen format.
  ///
  /// Example: `no_empty_block` -> `no-empty-block`
  static String toHyphenated(String ruleName) => ruleName.replaceAll('_', '-');

  /// Checks if a rule is suppressed at the file level via
  /// `// ignore_for_file:` directive.
  ///
  /// Searches the raw file content for an `ignore_for_file:` comment
  /// containing the given [ruleName] (supports both underscore and hyphen
  /// formats). Returns `true` if the entire file should be skipped.
  ///
  /// This is intentionally a string-based search on file content rather
  /// than an AST walk, for performance — it runs once per rule per file
  /// before any AST callbacks are registered.
  static bool isIgnoredForFile(String fileContent, String ruleName) {
    // Fast pre-check avoids regex compilation for the common case
    if (!fileContent.contains('ignore_for_file:')) return false;

    final hyphenatedName = toHyphenated(ruleName);

    // Match the rule name inside an ignore_for_file comment.
    // Uses \b word boundaries to avoid matching substrings
    // (e.g., `avoid_print` must not match `avoid_print_in_production`).
    final pattern = RegExp(
      r'//\s*ignore_for_file\s*:[^\n]*\b(?:'
      '${RegExp.escape(ruleName)}'
      '|'
      '${RegExp.escape(hyphenatedName)}'
      r')\b',
    );
    return pattern.hasMatch(fileContent);
  }

  /// Pattern that matches `// ignore:` or `// ignore_for_file:` comments
  /// with a trailing `//` comment or ` - ` explanation after the rule names.
  ///
  /// `custom_lint_builder` parses everything after the colon as rule names
  /// (splitting on commas), so trailing text like
  /// `// ignore: my_rule // reason` or `// ignore: my_rule - reason`
  /// causes the framework to store the extra text as part of the rule code,
  /// breaking the `Set.contains()` lookup.
  static final RegExp trailingCommentOnIgnore = RegExp(
    r'//\s*ignore(?:_for_file)?\s*:'
    r'(?:'
    r'[^/\n]+//[^\n]*' // trailing // comment
    r'|'
    r'[^\n]*?\s+-\s+\S[^\n]*' // trailing - separator
    r')$',
    multiLine: true,
  );

  /// Checks if a token has preceding comments containing an ignore directive
  /// for the given rule name (supports both underscore and hyphen formats).
  static bool hasIgnoreCommentOnToken(Token? token, String ruleName) {
    final String hyphenatedName = toHyphenated(ruleName);
    Token? comment = token?.precedingComments;

    while (comment != null) {
      final String text = comment.lexeme;
      if (text.contains('ignore:')) {
        if (text.contains(ruleName) || text.contains(hyphenatedName)) {
          return true;
        }
      }
      comment = comment.next;
    }
    return false;
  }

  /// Checks for ignore comments on the node or any of its ancestors.
  ///
  /// This handles cases where the ignore comment is on a parent expression,
  /// such as when suppressing a lint on a callback within a method chain.
  ///
  /// Also handles trailing ignore comments on the same line.
  ///
  /// Special handling for:
  /// - **MethodInvocation**: checks the `.` operator and method name tokens,
  ///   allowing ignore comments mid-chain:
  ///   ```dart
  ///   object
  ///       // ignore: rule_name
  ///       .method()
  ///   ```
  /// - **PropertyAccess**: similarly checks operator and property tokens
  /// - **CatchClause**: checks the token before the catch clause
  static bool hasIgnoreComment(AstNode node, String ruleName) {
    // Get line info for validation
    final root = node.root;
    LineInfo? lineInfo;
    if (root is CompilationUnit) {
      lineInfo = root.lineInfo;
    }

    final int nodeStartLine =
        lineInfo?.getLocation(node.offset).lineNumber ?? -1;

    // Check the node's own begin token
    if (_hasValidLeadingIgnoreComment(
      node.beginToken,
      ruleName,
      nodeStartLine,
      lineInfo,
    )) {
      return true;
    }

    // Special case for MethodInvocation: check operator and methodName tokens
    // This handles comments placed mid-chain like:
    //   object
    //       // ignore: rule_name
    //       .method()
    if (node is MethodInvocation) {
      final Token? operator = node.operator;
      if (operator != null) {
        final int operatorLine =
            lineInfo?.getLocation(operator.offset).lineNumber ?? nodeStartLine;
        if (_hasValidLeadingIgnoreComment(
          operator,
          ruleName,
          operatorLine,
          lineInfo,
        )) {
          return true;
        }
      }
      final int methodNameLine =
          lineInfo?.getLocation(node.methodName.offset).lineNumber ??
              nodeStartLine;
      if (_hasValidLeadingIgnoreComment(
        node.methodName.beginToken,
        ruleName,
        methodNameLine,
        lineInfo,
      )) {
        return true;
      }
    }

    // Special case for PropertyAccess: check operator and propertyName tokens
    if (node is PropertyAccess) {
      final int operatorLine =
          lineInfo?.getLocation(node.operator.offset).lineNumber ??
              nodeStartLine;
      if (_hasValidLeadingIgnoreComment(
        node.operator,
        ruleName,
        operatorLine,
        lineInfo,
      )) {
        return true;
      }
      final int propertyLine =
          lineInfo?.getLocation(node.propertyName.offset).lineNumber ??
              nodeStartLine;
      if (_hasValidLeadingIgnoreComment(
        node.propertyName.beginToken,
        ruleName,
        propertyLine,
        lineInfo,
      )) {
        return true;
      }
    }

    // Special case for CatchClause: check the token before the catch clause
    if (node is CatchClause) {
      final Token? prevToken = node.beginToken.previous;
      if (prevToken != null &&
          _hasValidLeadingIgnoreComment(
            prevToken,
            ruleName,
            nodeStartLine,
            lineInfo,
          )) {
        return true;
      }
    }

    // Walk up the parent chain to find comments on ancestor expressions
    AstNode? current = node.parent;
    Statement? containingStatement;
    while (current != null) {
      if (_hasValidLeadingIgnoreComment(
        current.beginToken,
        ruleName,
        nodeStartLine,
        lineInfo,
      )) {
        return true;
      }

      // Track the containing statement
      if (current is Statement) {
        containingStatement = current;
        break;
      }

      current = current.parent;
    }

    // Check for trailing same-line comments on the node itself
    if (_hasTrailingIgnoreComment(node, ruleName)) return true;

    // IMPORTANT: Also check trailing comments on the containing statement
    // This handles cases like: final x = 'value'; // ignore: rule
    // where the comment is at the end of the statement, not immediately after the value
    if (containingStatement != null) {
      if (_hasTrailingIgnoreComment(containingStatement, ruleName)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a token has a valid leading ignore comment for a node.
  ///
  /// A comment is a valid leading comment if:
  /// - It contains the ignore directive for the rule
  /// - It's on the same line as the target node's start, OR
  /// - It's on the line immediately before AND appears at the start of that line
  ///   (not as a trailing comment after other code)
  ///
  /// This prevents trailing comments (meant for previous siblings) from
  /// being incorrectly treated as leading comments for subsequent siblings.
  static bool _hasValidLeadingIgnoreComment(
    Token token,
    String ruleName,
    int nodeStartLine,
    LineInfo? lineInfo,
  ) {
    final String hyphenatedName = toHyphenated(ruleName);
    Token? comment = token.precedingComments;

    while (comment != null) {
      final String text = comment.lexeme;
      if (text.contains('ignore:')) {
        if (text.contains(ruleName) || text.contains(hyphenatedName)) {
          // If we have line info, validate the comment is a proper leading comment
          if (lineInfo != null && nodeStartLine > 0) {
            final commentLine = lineInfo.getLocation(comment.offset).lineNumber;

            if (commentLine == nodeStartLine) {
              // Same line as node start - valid leading comment
              return true;
            }

            if (commentLine == nodeStartLine - 1) {
              // Line before node - only valid if comment is at START of line
              // (i.e., it's a standalone comment, not trailing after other code)
              if (_isCommentAtLineStart(comment, token, lineInfo)) {
                return true;
              }
              // Comment is after other code on that line - it's a trailing comment
              // for that other code, not a leading comment for our node
            }
            // Comment is more than 1 line before - not a leading comment
          } else {
            // No line info available, fall back to original behavior
            return true;
          }
        }
      }
      comment = comment.next;
    }
    return false;
  }

  /// Checks if a comment appears at the start of its line (no code before it).
  ///
  /// A comment at the start of a line is likely a leading comment for the next
  /// statement. A comment NOT at the start (i.e., after code) is a trailing
  /// comment for the code before it on that line.
  ///
  /// [comment] is the comment token to check.
  /// [tokenHoldingComment] is the token whose precedingComments contains this
  /// comment (needed to find the previous code token).
  static bool _isCommentAtLineStart(
    Token comment,
    Token tokenHoldingComment,
    LineInfo lineInfo,
  ) {
    final commentLine = lineInfo.getLocation(comment.offset).lineNumber;

    // Check the token immediately before the token holding this comment
    // If that token ends on the same line as the comment, then the comment
    // is a trailing comment for that token, not a leading comment
    final Token? prevToken = tokenHoldingComment.previous;
    if (prevToken != null) {
      final prevTokenEndLine = lineInfo.getLocation(prevToken.end).lineNumber;
      if (prevTokenEndLine == commentLine) {
        // Previous token ends on the same line as the comment
        // So this is a trailing comment, not a leading comment
        return false;
      }
    }

    return true;
  }

  /// Checks for a trailing ignore comment on the same line as the node.
  ///
  /// Trailing comments are stored as `precedingComments` on subsequent tokens.
  /// We walk forward through tokens, checking each one's precedingComments,
  /// and verify the comment is on the same line as the node's end.
  static bool _hasTrailingIgnoreComment(AstNode node, String ruleName) {
    final String hyphenatedName = toHyphenated(ruleName);

    // Get line info from the compilation unit for line comparisons
    final root = node.root;
    if (root is! CompilationUnit) return false;
    final lineInfo = root.lineInfo;

    // Get the line number of the node's end
    final nodeEndLine = lineInfo.getLocation(node.end).lineNumber;

    // Walk forward through tokens looking for trailing comments on same line
    Token? currentToken = node.endToken.next;
    int tokensChecked = 0;
    const maxTokensToCheck =
        10; // Increased limit to find trailing comments further away

    while (currentToken != null && tokensChecked < maxTokensToCheck) {
      // Check this token's precedingComments
      final result = _checkTokenCommentsOnLine(
        currentToken,
        ruleName,
        hyphenatedName,
        nodeEndLine,
        lineInfo,
      );
      if (result == _CommentCheckResult.found) return true;
      if (result == _CommentCheckResult.pastLine) break;

      currentToken = currentToken.next;
      tokensChecked++;
    }

    return false;
  }

  /// Checks a token's preceding comments for an ignore directive on the target line.
  ///
  /// Returns:
  /// - [_CommentCheckResult.found] if matching ignore comment found on target line
  /// - [_CommentCheckResult.pastLine] if we've moved past the target line
  /// - [_CommentCheckResult.notFound] otherwise
  static _CommentCheckResult _checkTokenCommentsOnLine(
    Token token,
    String ruleName,
    String hyphenatedName,
    int targetLine,
    LineInfo lineInfo,
  ) {
    // First, check if this token has any comments on the target line
    Token? comment = token.precedingComments;
    while (comment != null) {
      final commentLine = lineInfo.getLocation(comment.offset).lineNumber;

      // Only consider comments on the same line as the node's end
      if (commentLine == targetLine) {
        final String text = comment.lexeme;
        if (text.contains('ignore:')) {
          if (text.contains(ruleName) || text.contains(hyphenatedName)) {
            return _CommentCheckResult.found;
          }
        }
      }

      comment = comment.next;
    }

    // After checking comments, if the token itself is past our target line, stop searching
    // Note: We check this AFTER examining comments because trailing comments on line N
    // are often attached as precedingComments to the first token of line N+1
    final tokenLine = lineInfo.getLocation(token.offset).lineNumber;
    if (tokenLine > targetLine + 1) {
      return _CommentCheckResult.pastLine;
    }

    return _CommentCheckResult.notFound;
  }
}

/// Result of checking a token's comments for an ignore directive.
enum _CommentCheckResult {
  /// Matching ignore comment found on target line.
  found,

  /// No matching comment found, continue searching.
  notFound,

  /// Moved past the target line, stop searching.
  pastLine,
}

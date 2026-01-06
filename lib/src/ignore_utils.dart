// ignore_for_file: always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Utilities for handling ignore comments with hyphen/underscore flexibility.
///
/// Dart lint rules conventionally use underscores (e.g., `avoid_print`),
/// but users sometimes write ignore comments with hyphens (e.g., `avoid-print`).
/// This utility allows rules to accept both formats.
class IgnoreUtils {
  IgnoreUtils._();

  /// Converts a rule name from underscore format to hyphen format.
  ///
  /// Example: `no_empty_block` -> `no-empty-block`
  static String toHyphenated(String ruleName) => ruleName.replaceAll('_', '-');

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
  /// Example where this is needed:
  /// ```dart
  /// // ignore: no-empty-block
  /// stream.listen((_) {});
  /// ```
  /// The empty block `{}` is nested inside the `listen()` call, so the
  /// ignore comment is on an ancestor node, not the block itself.
  ///
  /// Also handles trailing ignore comments on the same line:
  /// ```dart
  /// stream.listen((_) {}); // ignore: no-empty-block
  /// ```
  static bool hasIgnoreComment(AstNode node, String ruleName) {
    // Check the node's own begin token
    if (hasIgnoreCommentOnToken(node.beginToken, ruleName)) return true;

    // Walk up the parent chain to find comments on ancestor expressions
    AstNode? current = node.parent;
    while (current != null) {
      if (hasIgnoreCommentOnToken(current.beginToken, ruleName)) return true;
      // Stop at statement level - don't go higher
      if (current is Statement) break;
      current = current.parent;
    }

    // Check for trailing same-line comments (e.g., `{} // ignore: rule`)
    // These appear as precedingComments on the next token after the statement
    if (_hasTrailingIgnoreComment(node, ruleName)) return true;

    return false;
  }

  /// Checks for a trailing ignore comment on the same line as the node.
  ///
  /// Trailing comments like `// ignore: rule` at the end of a line are stored
  /// as `precedingComments` on the first token of the next line/statement.
  static bool _hasTrailingIgnoreComment(AstNode node, String ruleName) {
    // Find the ExpressionStatement containing this node
    // Note: Block is a Statement subclass, so we need to look for
    // ExpressionStatement specifically (which ends with `;`)
    AstNode? statement = node.parent;
    while (statement != null && statement is! ExpressionStatement) {
      // Stop if we hit a function/method body - no statement to check
      if (statement is FunctionBody) return false;
      statement = statement.parent;
    }
    if (statement == null) return false;

    // Get the token after the statement ends (typically first token of next line)
    final Token? nextToken = statement.endToken.next;
    if (nextToken == null) return false;

    final String hyphenatedName = toHyphenated(ruleName);

    // Check ALL preceding comments on the next token - any of them could be
    // a trailing ignore comment from the statement
    Token? comment = nextToken.precedingComments;
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
}

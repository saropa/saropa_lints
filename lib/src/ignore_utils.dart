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
  ///
  /// Special handling for CatchClause: also checks the token immediately
  /// before the catch clause (typically the `}` of the try block):
  /// ```dart
  /// try {
  ///   // code
  /// // ignore: avoid_swallowing_exceptions
  /// } on Exception catch (e) {
  ///   // empty
  /// }
  /// ```
  static bool hasIgnoreComment(AstNode node, String ruleName) {
    // Check the node's own begin token
    if (hasIgnoreCommentOnToken(node.beginToken, ruleName)) return true;

    // Special case for CatchClause: check the token before the catch clause
    // This handles the pattern where ignore comment is placed before the `}`
    // that closes the try block body:
    //   // ignore: rule
    //   } on Exception catch (e) { ... }
    if (node is CatchClause) {
      final Token? prevToken = node.beginToken.previous;
      if (prevToken != null && hasIgnoreCommentOnToken(prevToken, ruleName)) {
        return true;
      }
    }

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
  /// as `precedingComments` on the next token (which could be on the same line
  /// or the next line).
  ///
  /// This handles multiple scenarios:
  /// 1. Statement-level: `doSomething(); // ignore: rule`
  /// 2. Constructor args: `url: 'http://example.com', // ignore: rule`
  /// 3. List items: `WebsiteItem(url: 'http://test.com'), // ignore: rule`
  static bool _hasTrailingIgnoreComment(AstNode node, String ruleName) {
    final String hyphenatedName = toHyphenated(ruleName);

    // Strategy 1: Check the token immediately after this node's end token.
    // This handles cases like constructor arguments where the comment
    // follows the value directly: `url: 'http://...', // ignore: rule`
    if (_checkNextTokenForIgnore(node.endToken, ruleName, hyphenatedName)) {
      return true;
    }

    // Strategy 2: Walk up to find a statement-level container and check
    // the token after its end. This handles cases where the ignore comment
    // is at the end of a full statement: `doSomething(); // ignore: rule`
    AstNode? container = node.parent;
    while (container != null) {
      // Check various statement/declaration types that could end a line
      if (container is Statement ||
          container is VariableDeclaration ||
          container is FieldDeclaration ||
          container is MethodDeclaration ||
          container is CollectionElement) {
        if (_checkNextTokenForIgnore(
            container.endToken, ruleName, hyphenatedName)) {
          return true;
        }
      }
      // Stop if we hit a function/method body - don't go higher
      if (container is FunctionBody || container is CompilationUnit) break;
      container = container.parent;
    }

    return false;
  }

  /// Checks if the token after [endToken] has a preceding ignore comment.
  static bool _checkNextTokenForIgnore(
    Token endToken,
    String ruleName,
    String hyphenatedName,
  ) {
    final Token? nextToken = endToken.next;
    if (nextToken == null) return false;

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

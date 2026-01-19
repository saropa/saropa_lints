/// Utilities for detecting commented-out code vs prose comments.
///
/// These patterns are shared between:
/// - `capitalize_comment_start` - skips code comments, flags prose
/// - `avoid_commented_out_code` - flags code comments, skips prose
///
/// Both rules use the same heuristics to ensure consistent behavior.
library;

/// Patterns for detecting commented-out code in single-line comments.
///
/// Usage:
/// ```dart
/// final content = lexeme.substring(2).trim(); // Remove "//" prefix
/// if (CommentPatterns.isLikelyCode(content)) {
///   // This looks like commented-out code
/// }
/// if (CommentPatterns.isSpecialMarker(content)) {
///   // This is a TODO/FIXME/etc marker, skip it
/// }
/// ```
class CommentPatterns {
  CommentPatterns._();

  /// Pattern to detect commented-out code.
  ///
  /// This pattern detects common code constructs:
  /// - Identifier followed by code punctuation: `foo.bar`, `x = 5`
  /// - Dart keywords at start: `return`, `if (`, `final x`
  /// - Type declarations: `int value`, `String name`
  /// - Function/method calls: `doSomething()`, `list.add(item)`
  /// - Annotations: `@override`, `@deprecated`
  /// - Import/export: `import 'package:...'`
  /// - Class/enum: `class Foo {`, `enum Status {`
  /// - Block delimiters: `}`, `{`
  /// - Arrow functions: `=>`
  /// - Statement terminators: ends with `;`
  static final RegExp codePattern = RegExp(
    // Identifier immediately followed by code punctuation (no space)
    r'^[a-zA-Z_$][a-zA-Z0-9_$]*[:\.\(\[\{]|'
    // Assignment pattern: identifier = something
    r'^[a-zA-Z_$][a-zA-Z0-9_$]*\s*=\s*\S|'
    // Dart keywords at start of comment (control flow + declarations)
    r'^(return|if|else|for|while|switch|case|break|continue|final|const|var|late|await|async|throw|try|catch|finally|super|this|new|null|true|false|class|enum|extension|mixin|typedef|import|export|part|library)\b|'
    // Type keywords at start (common Dart types)
    r'^(void|int|double|String|bool|List|Map|Set|Future|Stream|dynamic|Object|Function|Iterable|num)\s+[a-zA-Z_]|'
    // Function/method call at end: foo() or foo();
    r'\w+\([^)]*\)\s*[;,]?\s*$|'
    // Ends with semicolon (statement)
    r';\s*$|'
    // Starts with annotation
    r'^@\w+|'
    // Contains arrow function
    r'=>|'
    // Block delimiters at boundaries
    r'^[\{\}]|[\{\}]\s*$',
  );

  /// Pattern for special comment markers that should always be skipped.
  ///
  /// These are intentional comments, not commented-out code:
  /// - TODO/FIXME/NOTE/HACK markers
  /// - Lint ignore directives
  /// - Spell checker directives
  /// - Documentation references
  static final RegExp specialMarkerPattern = RegExp(
    r'(TODO|FIXME|FIX|NOTE|HACK|XXX|BUG|OPTIMIZE|WARNING|CHANGED|REVIEW|DEPRECATED|IMPORTANT|MARK|See:|ignore:|ignore_for_file:|cspell:)',
    caseSensitive: false,
  );

  /// Returns true if the comment content looks like commented-out code.
  ///
  /// [content] should be the comment text with the "//" prefix removed and trimmed.
  static bool isLikelyCode(String content) {
    if (content.isEmpty) return false;
    return codePattern.hasMatch(content);
  }

  /// Returns true if the comment contains special markers (TODO, FIXME, etc).
  ///
  /// [content] should be the comment text with the "//" prefix removed and trimmed.
  static bool isSpecialMarker(String content) {
    if (content.isEmpty) return false;
    return specialMarkerPattern.hasMatch(content);
  }

  /// Returns true if the comment content starts with a lowercase letter.
  ///
  /// [content] should be the comment text with the "//" prefix removed and trimmed.
  static bool startsWithLowercase(String content) {
    if (content.isEmpty) return false;
    return _lowercaseStartPattern.hasMatch(content);
  }

  /// Pre-compiled pattern for detecting lowercase start.
  static final RegExp _lowercaseStartPattern = RegExp(r'^[a-z]');
}

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
  /// - Control flow with parens/blocks: `if (`, `for (`, `while {`
  /// - Simple statements: `return x`, `break;`, `throw error`
  /// - Declarations: `final x`, `const y`, `class Foo`
  /// - Import/export statements: `import 'package:...'`
  /// - Standalone keywords: `super`, `this`, `else`
  /// - Literals in code context: `null;`, `true,`, `false)` (not prose)
  /// - Type declarations: `int value`, `String name`
  /// - Function/method calls: `doSomething()`, `list.add(item)`
  /// - Annotations: `@override`, `@deprecated`
  /// - Block delimiters: `}`, `{`
  /// - Arrow functions: `=>`
  /// - Statement terminators: ends with `;`
  ///
  /// Note: Keywords in prose context are NOT matched:
  /// - `null is before...` ✓ prose (starts with keyword but followed by prose)
  /// - `return when done` ✓ prose (not followed by identifier/semicolon)
  /// - `true means success` ✓ prose (not followed by code punctuation)
  static final RegExp codePattern = RegExp(
    // Identifier immediately followed by code punctuation (no space)
    r'^[a-zA-Z_$][a-zA-Z0-9_$]*[:\.\(\[\{]|'
    // Assignment pattern: identifier = something
    r'^[a-zA-Z_$][a-zA-Z0-9_$]*\s*=\s*\S|'
    // Control flow keywords followed by opening paren or block
    r'^(if|for|while|switch|try)\s*[\(\{]|'
    // Simple statements (keywords that stand alone or with semicolon)
    r'^(return|break|continue|throw)\s*;|'
    // Return with common literals
    r'^return\s+(null|true|false|this|super|\d)\b|'
    // Declaration keywords followed by type or identifier
    r'^(final|const|var|late|await|async|class|enum|extension|mixin|typedef)\s+\w|'
    // Import/export/part/library statements
    r'^(import|export|part|library)\s+\S|'
    // Standalone keywords (likely code if just the keyword alone or with semicolon)
    r'^(super|this|new|else|case|finally)\b|'
    // Literal values only when standalone or with semicolon (not in prose)
    r'^(null|true|false)\s*[;,\)\]\}]|^(null|true|false)\s*$|'
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

  /// Returns true if the comment contains special task markers (like TO-DO or FIX-ME).
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

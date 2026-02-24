/// Utilities for detecting commented-out code vs prose comments.
///
/// These patterns are shared between:
/// - `prefer_capitalized_comment_start` - skips code comments, flags prose
/// - `prefer_no_commented_out_code` - flags code comments, skips prose
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
  /// - Identifier followed by code punctuation: `foo.bar`, `foo(`, `foo[`
  /// - Control flow with parens/blocks: `if (`, `for (`, `while {`
  /// - Simple statements: `return x`, `break;`, `throw error`
  /// - Declarations: `final x`, `const y`, `class Foo`
  /// - Import/export statements: `import 'package:...'`
  /// - Keywords with code syntax: `this.x`, `super(`, `new MyClass`
  /// - Literals in code context: `null;`, `true,`, `false)` (not prose)
  /// - Type declarations with code context: `int value;`, `String name =`
  /// - Function/method calls: `doSomething()`, `list.add(item)`
  /// - Annotations: `@override`, `@deprecated`
  /// - Block delimiters: `}`, `{`
  /// - Arrow functions: `=>`
  /// - Statement terminators: ends with `;`
  ///
  /// Note: Keywords and type names in prose context are NOT matched:
  /// - `this is non-null, other is null` ✓ prose
  /// - `Map the list of enum values` ✓ prose
  /// - `Iterable extensions` ✓ prose (no code punctuation after identifier)
  /// - `new set with the same elements` ✓ prose
  static final RegExp codePattern = RegExp(
    // Identifier immediately followed by code punctuation (no space).
    // Colon excluded: prose labels (OK:, BAD:, LINT:) cause too many false
    // positives. Dart loop labels (outerLoop:) are caught by keyword patterns.
    r'^[a-zA-Z_$][a-zA-Z0-9_$]*[\.\(\[\{]|'
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
    // Keywords with code syntax (not bare keywords in prose):
    //   this.x, this(, this;  /  super.x, super(, super;
    //   new ClassName (uppercase = constructor)
    //   else {, else if  /  case ...:  /  finally {
    r'^(super|this)\s*[\.;\,\(\)\[\]]|'
    r'^else\s*[\{]|^else\s+if\b|'
    r'^case\s+\S.*:\s*$|'
    r'^finally\s*[\{]|'
    r'^new\s+[A-Z]|'
    // Literal values only when standalone or with semicolon (not in prose)
    r'^(null|true|false)\s*[;,\)\]\}]|^(null|true|false)\s*$|'
    // Type names at start, but ONLY when followed by code context
    // (identifier + punctuation). Prevents "Map the list" or
    // "Iterable extensions" from matching.
    r'^(void|int|double|String|bool|List|Map|Set|Future|Stream|dynamic|Object|Function|Iterable|num)\s+[a-zA-Z_]\w*\s*[=;,\(\)\{\}<>\[\.]|'
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
  /// - Lint ignore and expect directives
  /// - Spell checker directives
  /// - Documentation references
  static final RegExp specialMarkerPattern = RegExp(
    r'(TODO|FIXME|FIX|NOTE|HACK|XXX|BUG|OPTIMIZE|WARNING|CHANGED|REVIEW|DEPRECATED|IMPORTANT|MARK|See:|ignore:|ignore_for_file:|expect_lint:|cspell:)',
    caseSensitive: false,
  );

  /// Returns true if the comment content looks like commented-out code.
  ///
  /// [content] should be the comment text with the "//" prefix removed and trimmed.
  ///
  /// A prose guard runs first: if the content contains multiple common
  /// English function words (articles, prepositions, conjunctions), it is
  /// treated as natural language even if it starts with a keyword or type.
  static bool isLikelyCode(String content) {
    if (content.isEmpty) return false;
    if (_isLikelyProse(content)) return false;
    return codePattern.hasMatch(content);
  }

  /// Common English function words that appear in prose but rarely in code.
  static const Set<String> _proseIndicators = <String>{
    'a',
    'an',
    'the',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'shall',
    'should',
    'may',
    'might',
    'can',
    'could',
    'of',
    'in',
    'for',
    'with',
    'to',
    'from',
    'by',
    'at',
    'on',
    'and',
    'or',
    'but',
    'nor',
    'not',
    'so',
    'yet',
    'that',
    'which',
    'who',
    'whom',
    'whose',
    'where',
    'when',
    'how',
    'each',
    'every',
    'all',
    'both',
    'few',
    'more',
    'most',
    'other',
    'some',
    'such',
    'than',
    'too',
    'very',
    'over',
    'into',
    'onto',
    'about',
    'between',
    'through',
  };

  /// Returns true if [content] looks like natural language prose.
  ///
  /// Requires 3+ words with at least 2 common English function words.
  ///
  /// **Important**: If the content contains strong code indicators
  /// (balanced parentheses, semicolons, arrow functions, or braces),
  /// the prose guard is bypassed entirely.  This prevents false negatives
  /// on comments like `// for (int i in list)` where `for` and `in` are
  /// both prose indicators but the overall pattern is clearly code.
  static bool _isLikelyProse(String content) {
    if (_hasStrongCodeIndicators(content)) return false;

    final List<String> words = content.split(RegExp(r'\s+'));
    if (words.length < 3) return false;

    int count = 0;
    for (final String word in words) {
      if (_proseIndicators.contains(word.toLowerCase())) {
        count++;
        if (count >= 2) return true;
      }
    }
    return false;
  }

  /// Returns true if [content] contains syntax that is unambiguously code.
  ///
  /// When these are present, the prose guard should not override the code
  /// pattern — the comment is almost certainly commented-out code even if
  /// it also contains English function words.
  static bool _hasStrongCodeIndicators(String content) {
    if (content.contains('(') && content.contains(')')) return true;
    if (content.contains(';')) return true;
    if (content.contains('=>')) return true;
    if (content.contains('{') || content.contains('}')) return true;
    return false;
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

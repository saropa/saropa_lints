// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: unreachable_from_main

/// Fixture file for apostrophe stylistic rules.
/// These are opinionated rules not included in any tier by default.
///
/// Rules tested:
/// - prefer_straight_apostrophe (strings)
/// - prefer_curly_apostrophe (strings)
/// - prefer_doc_curly_apostrophe (doc comments)
/// - prefer_doc_straight_apostrophe (doc comments)

// =============================================================================
// STRING APOSTROPHE RULES
// =============================================================================

class StringApostropheExamples {
  // --- prefer_straight_apostrophe ---
  // Warns when curly apostrophes are used in strings

  // BAD: Curly apostrophe in string (prefer_straight_apostrophe)
  // Note: This uses U+2019 (Right Single Quotation Mark)
  // expect_lint: prefer_straight_apostrophe
  String curlyInString = "It's a beautiful day";

  // GOOD: Straight apostrophe in string (U+0027)
  String straightInString = "It's a beautiful day";

  // --- prefer_curly_apostrophe ---
  // Warns when straight apostrophes are used in strings (opposite rule)

  // BAD: Straight apostrophe in contraction (prefer_curly_apostrophe)
  // expect_lint: prefer_curly_apostrophe
  String straightContraction = "Don't worry about it";

  // GOOD: Curly apostrophe in contraction (U+2019)
  String curlyContraction = "Don't worry about it";

  // More contraction examples
  // expect_lint: prefer_curly_apostrophe
  String cantExample = "I can't do that";

  // expect_lint: prefer_curly_apostrophe
  String wontExample = "I won't forget";

  // expect_lint: prefer_curly_apostrophe
  String itsExample = "It's working now";

  // Proper names with apostrophes
  // expect_lint: prefer_curly_apostrophe
  String obrienName = "O'Brien";

  // expect_lint: prefer_curly_apostrophe
  String clockTime = "It's 5 o'clock";
}

// =============================================================================
// DOC COMMENT APOSTROPHE RULES
// =============================================================================

// --- prefer_doc_curly_apostrophe ---
// Warns when straight apostrophes are used in doc comments

/// This class doesn't have any special behavior.
// expect_lint: prefer_doc_curly_apostrophe
class DocCommentStraightApostrophe {
  /// It's a simple method that won't fail.
  // expect_lint: prefer_doc_curly_apostrophe
  void simpleMethod() {}

  /// The user can't access this directly.
  // expect_lint: prefer_doc_curly_apostrophe
  void restrictedMethod() {}
}

// --- prefer_doc_straight_apostrophe ---
// Warns when curly apostrophes are used in doc comments (opposite rule)

/// This class doesn't have any special behavior.
// expect_lint: prefer_doc_straight_apostrophe
class DocCommentCurlyApostrophe {
  /// It's a simple method that won't fail.
  // expect_lint: prefer_doc_straight_apostrophe
  void simpleMethod() {}
}

// =============================================================================
// GOOD EXAMPLES (no lint expected)
// =============================================================================

/// This documentation uses straight apostrophes consistently.
/// It's the standard ASCII approach that works everywhere.
class GoodDocStraightApostrophe {
  /// This method doesn't trigger any lint.
  void goodMethod() {}
}

/// This documentation uses curly apostrophes consistently.
/// It's the typographic approach for better rendering.
class GoodDocCurlyApostrophe {
  /// This method doesn't trigger any lint.
  void goodMethod() {}
}

class GoodStringExamples {
  // No apostrophes - no lint
  String noApostrophe = "Hello world";

  // Code-like strings shouldn't trigger (no contractions)
  String codePath = "/user/config/file.txt";

  // Escaped apostrophe in single quotes - acceptable
  String escaped = 'It\'s fine';
}

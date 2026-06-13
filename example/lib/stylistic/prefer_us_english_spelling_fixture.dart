// ignore_for_file: unused_local_variable, unused_element

/// Fixture for the prefer_us_english_spelling rule.
///
/// The rule flags British spellings in comments and prose string literals and
/// leaves identifiers, URIs, single-token strings, and US spellings alone.

// =============================================================================
// BAD: British spellings in comments (should trigger lint)
// =============================================================================

void badComments() {
  // expect_lint: prefer_us_english_spelling
  // Initialise the cache before the first read.

  // expect_lint: prefer_us_english_spelling
  // Centre the dialogue box on screen.

  /// expect_lint: prefer_us_english_spelling
  /// The colour palette is built from the theme.
}

// =============================================================================
// BAD: British spellings in prose string literals (should trigger lint)
// =============================================================================

void badStrings() {
  // expect_lint: prefer_us_english_spelling
  final greeting = 'Saved your favourite colour';

  // expect_lint: prefer_us_english_spelling
  final status = 'Synchronising your travelled routes';
}

// =============================================================================
// OK: American spellings (should NOT trigger lint)
// =============================================================================

void goodExamples() {
  // Initialize the color palette and center the dialog.
  final greeting = 'Saved your favorite color';
  final status = 'Synchronizing your traveled routes';
}

// =============================================================================
// OK: false-positive guards (should NOT trigger lint)
// =============================================================================

// A British-looking word inside a URL is not author prose.
// See https://example.com/colour/centre for details.
const docsUrl = 'https://example.com/colour-guide';

// Single-token strings are identifiers / keys / enum names, not prose.
const colourKey = 'colour';
const Map<String, int> palette = {'colour': 1};

// A line the author already marked stays silent.
// Initialise the cache. // ignore: prefer_us_english_spelling

// cspell:ignore Initialise colour
// Initialise the colour palette (cspell directive present).

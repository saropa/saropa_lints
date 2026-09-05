// ignore_for_file: unused_element

/// Fixture for `no_internal_method_docs` lint rule.

// BAD: DartDoc on a private method — private members are never published by
// dartdoc, so `///` is dead documentation or a visibility mistake.
class _BadParser {
  // expect_lint: no_internal_method_docs
  /// Parses the raw header bytes into a [Header].
  void _parseHeader() {}
}

// BAD: DartDoc on a private top-level function.
// expect_lint: no_internal_method_docs
/// Computes the hash of the config block.
void _computeHash() {}

// BAD: DartDoc on a private named constructor.
class _BadSingleton {
  // expect_lint: no_internal_method_docs
  /// Internal constructor — only used by [instance].
  _BadSingleton._internal();
}

// BAD: DartDoc on a private getter (MethodDeclaration).
class _BadConfig {
  // expect_lint: no_internal_method_docs
  /// Returns the cached configuration.
  int get _cachedConfig => 42;
}

// GOOD: plain `//` comment on a private method — nothing to flag.
class _GoodParser {
  // Parses the raw header bytes; kept private since callers only need parse().
  void _parseHeader() {}
}

// GOOD: DartDoc on a PUBLIC method — this is the correct use of `///`.
class GoodPublicApi {
  /// Parses the input string and returns the result.
  void parse() {}
}

// GOOD: DartDoc on a public top-level function — correct.
/// Public entry point for the library.
void initialize() {}

// GOOD: No doc comment at all on a private method — nothing to flag.
class _GoodNoComment {
  void _helper() {}
}

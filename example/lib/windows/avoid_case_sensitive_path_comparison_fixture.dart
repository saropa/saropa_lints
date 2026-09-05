// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: unnecessary_null_comparison, dead_code

/// Fixture for `avoid_case_sensitive_path_comparison` lint rule.
///
/// Uses `// LINT:` and `// LINT_NOT:` markers for machine-verified assertions
/// via `assertFixtureMarkers` + `runRuleResolved`.

// --- BAD: case-sensitive string-to-string path comparisons ---

/// Direct path variable comparison without case normalization.
void badStringComparison(String filePath, String otherPath) {
  // LINT: avoid_case_sensitive_path_comparison
  if (filePath == otherPath) {}
}

/// Not-equal string-to-string path comparison.
void badNotEqualComparison(String dirPath, String expected) {
  // LINT: avoid_case_sensitive_path_comparison
  if (dirPath != expected) {}
}

// --- GOOD: null checks on path variables are NOT path comparisons ---

/// Null equality check — this is a nullability guard, not a case comparison.
void goodNullCheck(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePathUrl == null) return;
}

/// Reversed null equality check.
void goodNullCheckReversed(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (null == filePathUrl) return;
}

/// Not-null check.
void goodNotNullCheck(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePathUrl != null) {
    // use it
  }
}

/// Reversed not-null check.
void goodNotNullCheckReversed(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (null != filePathUrl) {
    // use it
  }
}

// --- GOOD: non-string comparisons on path variables ---

/// Integer comparison — not a string comparison.
void goodIntegerComparison(int pathIndex) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathIndex == 0) return;
}

/// Boolean comparison — not a string comparison.
void goodBooleanComparison(bool isPathValid) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (isPathValid == true) return;
}

/// Double comparison — not a string comparison.
void goodDoubleComparison(double pathLength) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathLength == 0.0) return;
}

/// Enum comparison — not a string comparison.
enum PathType { absolute, relative }

void goodEnumComparison(PathType dirPathType) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (dirPathType == PathType.absolute) return;
}

// --- GOOD: already using case normalization ---

/// toLowerCase() applied — no lint.
void goodWithLowerCase(String filePath, String otherPath) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePath.toLowerCase() == otherPath.toLowerCase()) {}
}

/// toUpperCase() applied — no lint.
void goodWithUpperCase(String filePath, String otherPath) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePath.toUpperCase() == otherPath.toUpperCase()) {}
}

// --- GOOD: root-detection idiom — both sides come from the same
// Directory API call so casing is always consistent (standard Dart
// filesystem-root traversal test). ---

/// `dir.path != dir.parent.path` — walks up to the filesystem root.
void goodRootDetectionIdiom(_FakeDirectory dir) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  while (dir.path != dir.parent.path) {
    dir = dir.parent;
  }
}

/// Reversed root-detection idiom — same idiom, operands swapped.
void goodRootDetectionIdiomReversed(_FakeDirectory dir) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (dir.parent.path == dir.path) {
    return;
  }
}

/// Mismatched base expressions — `a.path == b.parent.path` is NOT the
/// root-detection idiom because `a` and `b` are different variables.
/// Casing consistency is not guaranteed across different directories.
void badMismatchedRootDetection(_FakeDirectory a, _FakeDirectory b) {
  // LINT: avoid_case_sensitive_path_comparison
  if (a.path == b.parent.path) {}
}

/// Reversed mismatched base — `b.parent.path == a.path` is equally wrong.
void badMismatchedRootDetectionReversed(
  _FakeDirectory a,
  _FakeDirectory b,
) {
  // LINT: avoid_case_sensitive_path_comparison
  if (b.parent.path == a.path) {}
}

class _FakeDirectory {
  _FakeDirectory(this.path, this.parent);
  final String path;
  final _FakeDirectory parent;
}

// --- GOOD: string literal without a path separator is a CLI flag or
// label, not a filesystem path — the word "path" in the name (e.g.
// '--json-file-path') must not trigger the heuristic. ---

/// CLI flag comparison — literal has no '/' or '\\', so it is not a path.
void goodCliFlagComparison(String arg) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (arg == '--json-file-path') {}
}

// --- GOOD: Dart import URI comparison — import specifiers are
// case-sensitive by language spec, so this is not a filesystem path
// comparison that needs case normalization. ---

/// Import URI comparison — case sensitivity here is correct as-is.
void goodImportUriComparison(String namedUri, String pathFirst) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (namedUri == pathFirst) {}
}

/// Import URI comparison via an abbreviated for-each loop variable
/// ('imp') that doesn't itself carry "import"/"uri" in its name — the
/// guard falls back to inspecting the loop's iterable expression.
void goodImportUriComparisonLoopVariable(
  List<String> imports,
  String? pathFirst,
) {
  for (final imp in imports) {
    // LINT_NOT: avoid_case_sensitive_path_comparison
    if (pathFirst != null && imp == pathFirst) {}
  }
}

// --- GOOD: "path" embedded inside an unrelated word must not trigger
// the heuristic — only a standalone camelCase "path"/"Path" word
// component counts (see _hasPathAsWord). ---

/// "pathology"/"empathy" are unrelated words that happen to contain the
/// substring "path" — this is a plain string comparison, not a path
/// comparison, so it must not lint even though both sides are strings.
void goodUnrelatedWordContainingPath(String pathologyReport, String empathyNote) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathologyReport == empathyNote) {}
}

// --- Total count assertion: exactly 2 BAD sites should fire ---
// LINT_COUNT: avoid_case_sensitive_path_comparison 4

void main() {}

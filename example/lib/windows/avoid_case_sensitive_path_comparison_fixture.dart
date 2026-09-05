// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: unnecessary_null_comparison, dead_code

/// Fixture for `avoid_case_sensitive_path_comparison` lint rule.
///
/// Tests that null/boolean checks on path-named variables do NOT fire,
/// while actual string-to-string comparisons DO fire.

// --- BAD: case-sensitive string-to-string path comparisons ---

/// Direct path variable comparison without case normalization.
void badStringComparison(String filePath, String otherPath) {
  if (filePath == otherPath) {} // LINT
}

/// Not-equal string-to-string path comparison.
void badNotEqualComparison(String dirPath, String expected) {
  if (dirPath != expected) {} // LINT
}

// --- GOOD: null checks on path variables are NOT path comparisons ---

/// Null equality check — this is a nullability guard, not a case comparison.
void goodNullCheck(String? filePathUrl) {
  if (filePathUrl == null) return;
}

/// Reversed null equality check.
void goodNullCheckReversed(String? filePathUrl) {
  // ignore: prefer_null_aware_method_calls
  if (null == filePathUrl) return;
}

/// Not-null check.
void goodNotNullCheck(String? filePathUrl) {
  if (filePathUrl != null) {
    // use it
  }
}

/// Reversed not-null check.
void goodNotNullCheckReversed(String? filePathUrl) {
  if (null != filePathUrl) {
    // use it
  }
}

// --- GOOD: non-string comparisons on path variables ---

/// Integer comparison — not a string comparison.
void goodIntegerComparison(int pathIndex) {
  if (pathIndex == 0) return;
}

/// Boolean comparison — not a string comparison.
void goodBooleanComparison(bool isPathValid) {
  if (isPathValid == true) return;
}

// --- GOOD: already using case normalization ---

/// toLowerCase() applied — no lint.
void goodWithLowerCase(String filePath, String otherPath) {
  if (filePath.toLowerCase() == otherPath.toLowerCase()) {}
}

void main() {}

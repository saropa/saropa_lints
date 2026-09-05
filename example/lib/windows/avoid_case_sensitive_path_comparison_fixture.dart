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

// --- Total count assertion: exactly 2 BAD sites should fire ---
// LINT_COUNT: avoid_case_sensitive_path_comparison 2

void main() {}

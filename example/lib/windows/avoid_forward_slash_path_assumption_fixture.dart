// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_forward_slash_path_assumption` lint rule.
///
/// The rule is skipped entirely in a Flutter app that has only `android/`
/// and/or `ios/` platform folders (project-level gate, not expressible in a
/// fixture). The cases below apply to projects that can run on Windows.

String _join(String a, String b) => a;

// BAD: interpolated path built with "/".
void _badInterpolation(String cachedContainerPath, String imageSubdirectory) {
  // expect_lint: avoid_forward_slash_path_assumption
  final String p = '$cachedContainerPath/$imageSubdirectory';
}

// BAD: concatenated path built with "/".
void _badConcatenation(String directory, String filename) {
  // expect_lint: avoid_forward_slash_path_assumption
  final String p = directory + '/' + filename;
}

// GOOD: path joined with a path-aware helper.
void _goodJoin(String directory, String filename) {
  final String p = _join(directory, filename);
}

// GOOD: not a path (no path-like variable name).
void _goodNotPath(String a, String b) {
  final String s = '$a/$b';
}

void main() {}

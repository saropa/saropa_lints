// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages

/// Fixture for `prefer_dark_mode_colors` lint rule.

// BAD: Hardcoded light-only colors
// expect_lint: prefer_dark_mode_colors
const badColor = 0xFF000000;

// GOOD: Theme-aware colors
// Color goodColor(BuildContext c) => Theme.of(c).colorScheme.surface;

void main() {}

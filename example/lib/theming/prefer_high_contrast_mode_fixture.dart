// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages

/// Fixture for `prefer_high_contrast_mode` lint rule.

// BAD: No high-contrast consideration
// expect_lint: prefer_high_contrast_mode
const badContrast = 0.5;

// GOOD: Respect high contrast
// final goodContrast = MediaQuery.highContrastOf(context) ? 0.9 : 0.5;

void main() {}

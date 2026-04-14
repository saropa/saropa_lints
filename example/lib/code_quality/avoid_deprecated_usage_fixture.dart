// Fixture for avoid_deprecated_usage.
// ignore_for_file: unused_local_variable, depend_on_referenced_packages

import 'package:flutter/material.dart';

// BAD: Using deprecated API from another package (e.g. headline1 deprecated in Material3).
// LINT: avoid_deprecated_usage
void badDeprecatedUsage(BuildContext context) {
  final theme = Theme.of(context).textTheme;
  final headline = theme.headline1; // deprecated; use displayLarge
}

// GOOD: Using non-deprecated API.
void goodUsage(BuildContext context) {
  final theme = Theme.of(context).textTheme;
  final headline = theme.displayLarge;
}

// GOOD: Same-package deprecated (ignored by rule).
@Deprecated('Use newApi')
void myDeprecatedMethod() {}

void callOwnDeprecated() {
  myDeprecatedMethod(); // no lint: same package
}

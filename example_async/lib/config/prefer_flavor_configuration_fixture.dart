// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_flavor_configuration` lint rule.

// BAD: No flavor-based configuration for multi-environment
// expect_lint: prefer_flavor_configuration
const isProduction = true; // hardcoded, not flavor-driven

// GOOD: Flavor-based configuration
const isProduction = String.fromEnvironment('FLAVOR') == 'prod';

void main() {}

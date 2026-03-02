// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_compile_time_config` lint rule.

// BAD: Runtime-only config where compile-time could be used
// expect_lint: prefer_compile_time_config
const apiHost = 'https://api.example.com'; // from runtime env only

// GOOD: Compile-time configuration
const apiHost = String.fromEnvironment('API_HOST', defaultValue: 'https://api.example.com');

void main() {}

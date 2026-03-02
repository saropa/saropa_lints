// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_geolocation_coarse_location` lint rule.

// BAD: Fine accuracy when coarse is enough
// expect_lint: prefer_geolocation_coarse_location
void bad() { /* request with LocationAccuracy.high */ }

// GOOD: Coarse when only approximate location needed
void good() { /* request with LocationAccuracy.low */ }

void main() {}

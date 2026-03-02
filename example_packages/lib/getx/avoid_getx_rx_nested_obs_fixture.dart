// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_getx_rx_nested_obs` lint rule.

// BAD: Nested .obs / Rx inside Obx
// expect_lint: avoid_getx_rx_nested_obs
final bad = 0.obs;

// GOOD: Flat observable, no nesting
final good = 0.obs;

void main() {}

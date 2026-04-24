// ignore_for_file: avoid_print
// Test fixture for: prefer_extracting_repeated_map_lookup
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

void badRepeatedLookup(Map<String, int> config) {
  print(config['timeout']);
  print(config['timeout']);
  // expect_lint: prefer_extracting_repeated_map_lookup
  print(config['timeout']);
}

void goodExtracted(Map<String, int> config) {
  final timeout = config['timeout'];
  print(timeout);
  print(timeout);
  print(timeout);
}

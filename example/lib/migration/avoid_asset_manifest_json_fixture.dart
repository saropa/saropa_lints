// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: avoid_asset_manifest_json
// Test fixture for: avoid_asset_manifest_json
// Source: lib\src\rules\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Direct string literal usage of removed AssetManifest.json
// expect_lint: avoid_asset_manifest_json
void _badStringLiteral() async {
  final manifest = await rootBundle.loadString('AssetManifest.json');
}

// BAD: In a variable assignment
// expect_lint: avoid_asset_manifest_json
void _badVariable() {
  const path = 'AssetManifest.json';
}

// GOOD: Using the binary format
void _goodBinFormat() async {
  final manifest = await rootBundle.loadString('AssetManifest.bin');
}

// GOOD: Other JSON files are fine
void _goodOtherJson() async {
  final config = await rootBundle.loadString('config.json');
}

// FALSE POSITIVE: Different asset manifest file
void _fpCustomManifest() async {
  final custom = await rootBundle.loadString('CustomAssetManifest.json');
}

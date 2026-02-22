// ignore_for_file: unused_local_variable, unused_element, avoid_hardcoded_credentials
// ignore_for_file: prefer_dropdown_initial_value, avoid_asset_manifest_json
// ignore_for_file: prefer_on_pop_with_result
// Test fixture for migration rules

import 'flutter_mocks.dart';

// =============================================================================
// avoid_asset_manifest_json
// =============================================================================

void assetManifestBad() async {
  // LINT: Direct string literal usage of removed AssetManifest.json
  final manifest = await rootBundle.loadString('AssetManifest.json');

  // LINT: In a variable assignment
  const path = 'AssetManifest.json';
}

void assetManifestGood() async {
  // OK: Using the binary format
  final manifest = await rootBundle.loadString('AssetManifest.bin');

  // OK: Other JSON files are fine
  final config = await rootBundle.loadString('config.json');

  // OK: Partial match should not trigger
  final notes = 'See AssetManifest.bin for details';

  // OK: Different asset manifest file
  final custom = await rootBundle.loadString('CustomAssetManifest.json');
}

// =============================================================================
// prefer_dropdown_initial_value
// =============================================================================

Widget dropdownBad() {
  // LINT: Using deprecated 'value' parameter
  return DropdownButtonFormField<String>(
    value: 'hello',
    onChanged: (v) {},
    items: [],
  );
}

Widget dropdownGood() {
  // OK: Using the new 'initialValue' parameter
  return DropdownButtonFormField<String>(
    initialValue: 'hello',
    onChanged: (v) {},
    items: [],
  );
}

Widget dropdownFalsePositives() {
  // OK: DropdownButton (not DropdownButtonFormField) has 'value' legitimately
  return DropdownButton<String>(
    value: 'hello',
    onChanged: (v) {},
    items: [],
  );
}

// =============================================================================
// prefer_on_pop_with_result
// =============================================================================

void onPopBad() {
  // LINT: Using deprecated 'onPop' named argument
  MaterialPageRoute(
    builder: (context) => const Text('detail'),
    onPop: () {},
  );
}

void onPopGood() {
  // OK: Using the new 'onPopWithResult' parameter
  MaterialPageRoute(
    builder: (context) => const Text('detail'),
    onPopWithResult: (result) {},
  );
}

void onPopFalsePositives() {
  // OK: No onPop parameter at all
  MaterialPageRoute(
    builder: (context) => const Text('detail'),
  );

  // OK: A map literal with 'onPop' key is not a named argument
  final map = {'onPop': true};
}

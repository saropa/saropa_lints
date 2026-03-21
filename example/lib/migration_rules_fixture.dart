// ignore_for_file: unused_local_variable, unused_element, avoid_hardcoded_credentials
// ignore_for_file: prefer_dropdown_initial_value, avoid_asset_manifest_json
// ignore_for_file: prefer_on_pop_with_result
// ignore_for_file: prefer_platform_menu_bar_child, prefer_keepalive_dispose
// ignore_for_file: prefer_context_menu_builder, prefer_pan_axis
// ignore_for_file: prefer_button_style_icon_alignment, prefer_key_event
// ignore_for_file: prefer_m3_text_theme
// ignore_for_file: prefer_overflow_bar_over_button_bar
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

// =============================================================================
// prefer_platform_menu_bar_child
// =============================================================================

Widget platformMenuBarBad() {
  // LINT: Using deprecated 'body' parameter
  return PlatformMenuBar(menus: [], body: const Text('app'));
}

Widget platformMenuBarGood() {
  // OK: Using the new 'child' parameter
  return PlatformMenuBar(menus: [], child: const Text('app'));
}

// =============================================================================
// prefer_keepalive_dispose
// =============================================================================

void keepaliveBad() {
  // LINT: Using deprecated 'release()' method
  final handle = KeepAliveHandle();
  handle.release();
}

void keepaliveGood() {
  // OK: Using the replacement 'dispose()' method
  final handle = KeepAliveHandle();
  handle.dispose();
}

// =============================================================================
// prefer_context_menu_builder
// =============================================================================

Widget contextMenuBad() {
  // LINT: Using deprecated 'previewBuilder' parameter
  return CupertinoContextMenu(
    previewBuilder: (ctx, anim, child) => child,
    child: const Text('press'),
  );
}

Widget contextMenuGood() {
  // OK: Using the new 'builder' parameter
  return CupertinoContextMenu(
    builder: (ctx, anim) => const Text('preview'),
    child: const Text('press'),
  );
}

// =============================================================================
// prefer_pan_axis
// =============================================================================

Widget panAxisBad() {
  // LINT: Using deprecated 'alignPanAxis' parameter
  return InteractiveViewer(alignPanAxis: true, child: const Text('c'));
}

Widget panAxisGood() {
  // OK: Using the new 'panAxis' enum parameter
  return InteractiveViewer(panAxis: PanAxis.aligned, child: const Text('c'));
}

// =============================================================================
// prefer_button_style_icon_alignment
// =============================================================================

Widget iconAlignmentBad() {
  // LINT: Using deprecated 'iconAlignment' on ElevatedButton
  return ElevatedButton(
    onPressed: () {},
    iconAlignment: IconAlignment.end,
    child: const Text('btn'),
  );
}

Widget iconAlignmentGood() {
  // OK: Using ButtonStyle.iconAlignment via style parameter
  return ElevatedButton.icon(
    onPressed: () {},
    icon: const Icon(null),
    label: const Text('btn'),
    style: ElevatedButton.styleFrom(iconAlignment: IconAlignment.end),
  );
}

// =============================================================================
// prefer_key_event
// =============================================================================

// LINT: Using deprecated RawKeyboardListener
Widget keyEventBad() {
  return RawKeyboardListener(
    focusNode: FocusNode(),
    onKey: (event) {},
    child: const Text('l'),
  );
}

// OK: Using KeyboardListener (replacement)
Widget keyEventGood() {
  return KeyboardListener(
    focusNode: FocusNode(),
    onKeyEvent: (event) {},
    child: const Text('l'),
  );
}

// =============================================================================
// prefer_m3_text_theme
// =============================================================================

void textThemeBad() {
  // LINT: Using deprecated 2018-era 'headline1' property
  final theme = ThemeData();
  final style = theme.textTheme.headline1;
}

void textThemeGood() {
  // OK: Using M3 'displayLarge' property
  final theme = ThemeData();
  final style = theme.textTheme.displayLarge;
}

// =============================================================================
// prefer_overflow_bar_over_button_bar
// =============================================================================

// LINT: Prefer OverflowBar instead of ButtonBar
Widget overflowBarBad() {
  return ButtonBar(
    children: [
      TextButton(onPressed: () {}, child: Text('OK')),
    ],
  );
}

Widget overflowBarGood() {
  return OverflowBar(
    children: [
      TextButton(onPressed: () {}, child: Text('OK')),
    ],
  );
}

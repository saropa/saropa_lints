// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_const_constructors, unused_import

// Test fixture for: avoid_color_only_meaning
// Source: lib/src/rules/ui/accessibility_rules.dart
//
// Covers the false-positive regression documented in
// bugs/avoid_color_only_meaning_false_positive_theme_dark_mode_conditional.md:
// theme / platform / directionality ternaries must NOT trigger the rule
// because the user only ever sees one branch per session — there is no
// information being encoded in color.
//
// Also covers state-control companions: Checkbox/Switch/Radio should count as
// non-color indicators when paired with conditional background colors.
//
// Wrapper companions (Common*/App*/Brand* + known suffix): see
// plan/history/2026.04/2026.04.25/avoid_color_only_meaning_false_positive_project_wrapper_widgets.md

import 'package:saropa_lints_example/flutter_mocks.dart';

final bool isError = false;
final bool isSelected = false;
final BuildContext context = BuildContext();

class ThemeUtils {
  // Stub for the real helper used in d:/src/contacts — reads MediaQuery at
  // runtime. The rule only inspects the identifier name, not its impl.
  static bool get isDarkMode => false;
}

class CommonIcon extends StatelessWidget {
  const CommonIcon({required this.iconCommon, super.key});
  final dynamic iconCommon;

  @override
  Widget build(BuildContext context) => Icon(iconCommon);
}

class CommonText extends StatelessWidget {
  const CommonText(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

class BrandIcon extends StatelessWidget {
  const BrandIcon({required this.iconData, super.key});
  final dynamic iconData;

  @override
  Widget build(BuildContext context) => Icon(iconData);
}

class AppText extends StatelessWidget {
  const AppText(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

class AppCustomLabel extends StatelessWidget {
  const AppCustomLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

// GOOD: dark-mode ternary is theme adaptation, not state. NO lint.
void _goodDarkMode() {
  ColoredBox(
    color: ThemeUtils.isDarkMode ? Colors.black : Colors.white,
    child: SizedBox(width: 10, height: 10),
  );
}

// GOOD: Brightness comparison is theme adaptation. NO lint.
void _goodBrightnessCompare() {
  ColoredBox(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white,
    child: SizedBox(width: 10, height: 10),
  );
}

// GOOD: platformBrightness via MediaQuery is theme adaptation. NO lint.
void _goodPlatformBrightness() {
  ColoredBox(
    color: MediaQuery.of(context).platformBrightness == Brightness.dark
        ? Colors.black
        : Colors.white,
    child: SizedBox(width: 10, height: 10),
  );
}

// GOOD: Platform.isIOS is platform adaptation, not state. NO lint.
void _goodPlatformCheck() {
  ColoredBox(
    color: Platform.isIOS ? Colors.grey : Colors.blue,
    child: SizedBox(width: 10, height: 10),
  );
}

// BAD: genuine state ternary on ColoredBox with no companion. SHOULD lint.
// expect_lint: avoid_color_only_meaning
void _badStateTernary() {
  ColoredBox(
    color: isError ? Colors.red : Colors.green,
    child: SizedBox(width: 24, height: 24),
  );
}

// BAD: isSelected state ternary with no companion. SHOULD lint.
// expect_lint: avoid_color_only_meaning
void _badSelectedTernary() {
  ColoredBox(
    color: isSelected ? Colors.blue : Colors.grey,
    child: SizedBox(width: 24, height: 24),
  );
}

// GOOD: state ternary WITH Icon companion — existing companion-walk
// behavior preserved. NO lint.
void _goodStateWithCompanion() {
  ColoredBox(
    color: isError ? Colors.red : Colors.green,
    child: Icon(Icons.add),
  );
}

// GOOD: Checkbox communicates selection state independent of color.
void _goodStateWithCheckboxCompanion() {
  Material(
    color: isSelected ? Colors.blue : Colors.grey,
    child: Row(
      children: <Widget>[
        Checkbox(value: isSelected, onChanged: (_) {}),
        SizedBox(width: 8, height: 8),
      ],
    ),
  );
}

// GOOD: Switch communicates on/off state independent of color.
void _goodStateWithSwitchCompanion() {
  Material(
    color: isSelected ? Colors.green : Colors.grey,
    child: Row(
      children: <Widget>[Switch(value: isSelected, onChanged: (_) {})],
    ),
  );
}

// GOOD: Radio communicates selected choice independent of color.
void _goodStateWithRadioCompanion() {
  Material(
    color: isSelected ? Colors.orange : Colors.grey,
    child: Row(
      children: <Widget>[
        Radio<bool>(value: true, groupValue: isSelected, onChanged: (_) {}),
      ],
    ),
  );
}

// GOOD: project wrapper around Icon + icon swap is a non-color indicator.
void _goodStateWithCommonIconWrapper() {
  Material(
    color: isSelected ? Colors.green : Colors.white,
    child: Row(
      children: <Widget>[
        CommonIcon(iconCommon: isSelected ? Icons.check : Icons.search),
        const SizedBox(width: 8, height: 8),
      ],
    ),
  );
}

// GOOD: project wrapper around Text is also a non-color indicator.
void _goodStateWithCommonTextWrapper() {
  Material(
    color: isSelected ? Colors.blue : Colors.grey,
    child: Row(children: <Widget>[const CommonText('Selected state')]),
  );
}

// GOOD: Brand-prefixed wrapper around Icon should be recognized.
void _goodStateWithBrandIconWrapper() {
  Material(
    color: isSelected ? Colors.orange : Colors.grey,
    child: Row(children: <Widget>[const BrandIcon(iconData: Icons.check)]),
  );
}

// GOOD: App-prefixed wrapper around Text should be recognized.
void _goodStateWithAppTextWrapper() {
  Material(
    color: isSelected ? Colors.purple : Colors.grey,
    child: Row(children: <Widget>[const AppText('Enabled')]),
  );
}

// BAD: Prefix alone should not suppress lint when suffix is unknown.
// expect_lint: avoid_color_only_meaning
void _badStateWithUnknownAppWrapper() {
  Material(
    color: isSelected ? Colors.teal : Colors.grey,
    child: Row(children: <Widget>[const AppCustomLabel('State')]),
  );
}

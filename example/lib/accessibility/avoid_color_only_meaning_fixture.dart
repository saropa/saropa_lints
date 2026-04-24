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

import 'package:saropa_lints_example/flutter_mocks.dart';

final bool isError = false;
final bool isSelected = false;
final BuildContext context = BuildContext();

class ThemeUtils {
  // Stub for the real helper used in d:/src/contacts — reads MediaQuery at
  // runtime. The rule only inspects the identifier name, not its impl.
  static bool get isDarkMode => false;
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
    color: Platform.isIOS ? Colors.grey : Colors.blueGrey,
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

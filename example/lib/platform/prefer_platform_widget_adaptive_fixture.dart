// ignore_for_file: unused_element
// Test fixture for: prefer_platform_widget_adaptive (near misses only).
//
// The rule requires widgets resolved from `package:flutter`, which this
// example package does not depend on. Reporting cases are covered by
// `test/rules/config/prefer_platform_widget_adaptive_behavior_test.dart`.

class MaterialApp {
  const MaterialApp();
}

class Switch {
  const Switch();
}

// GOOD: MaterialApp has no adaptive counterpart.
Object _app() => const MaterialApp();

// GOOD: a project class that merely shares a Flutter widget's name.
Object _localSwitch() => const Switch();

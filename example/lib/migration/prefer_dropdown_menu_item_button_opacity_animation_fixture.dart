// ignore_for_file: unused_element, unused_field
// Test fixture for: prefer_dropdown_menu_item_button_opacity_animation
// Source: lib/src/rules/config/migration_rules.dart

import '../flutter_mocks.dart';

class _BadNullableField extends State<DropdownMenuItemButton<String>> {
  // expect_lint: prefer_dropdown_menu_item_button_opacity_animation
  CurvedAnimation? opacityAnimation;
}

class _BadBangOnField extends State<DropdownMenuItemButton<String>> {
  late CurvedAnimation opacityAnimation;

  void tick() {
    // expect_lint: prefer_dropdown_menu_item_button_opacity_animation
    opacityAnimation!.value;
  }
}

void badPropertyBang(DropdownMenuItemButton<String> item) {
  // expect_lint: prefer_dropdown_menu_item_button_opacity_animation
  item.opacityAnimation!.value;
}

class _GoodState extends State<DropdownMenuItemButton<String>> {
  late CurvedAnimation opacityAnimation;

  void tick() {
    opacityAnimation.value;
  }
}

class _FalsePositiveOtherState extends State<StatefulWidget> {
  CurvedAnimation? opacityAnimation;
}

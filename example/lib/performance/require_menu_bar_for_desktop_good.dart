// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_const_constructors, avoid_unused_constructor_parameters
// Compliant example for require_menu_bar_for_desktop, kept in its own file.
// The rule is whole-file: a PlatformMenuBar anywhere suppresses the report, so
// this must not share a file with the BAD fixture.
import 'package:saropa_lints_example/flutter_mocks.dart';

// GOOD: Should NOT trigger require_menu_bar_for_desktop
void goodMenuBar() {
  MaterialApp(
    builder: (context, child) => PlatformMenuBar(
      menus: [],
      child: child!,
    ),
    home: Scaffold(),
  );
}

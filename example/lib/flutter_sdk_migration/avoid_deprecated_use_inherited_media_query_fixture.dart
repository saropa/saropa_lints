// ignore_for_file: unused_element, undefined_named_parameter, unused_element_parameter
// Test fixture for: avoid_deprecated_use_inherited_media_query
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart

import '../flutter_mocks.dart';

Widget useInheritedMediaQueryBad() {
  // expect_lint: avoid_deprecated_use_inherited_media_query
  return MaterialApp(useInheritedMediaQuery: true, home: const _Empty());
}

Widget useInheritedMediaQueryBadCupertino() {
  // expect_lint: avoid_deprecated_use_inherited_media_query
  return CupertinoApp(useInheritedMediaQuery: true, home: const _Empty());
}

Widget useInheritedMediaQueryBadWidgets() {
  // expect_lint: avoid_deprecated_use_inherited_media_query
  return WidgetsApp(useInheritedMediaQuery: true, home: const _Empty());
}

Widget useInheritedMediaQueryGood() {
  return MaterialApp(home: const _Empty());
}

class _Empty extends Widget {
  const _Empty();
}

class CupertinoApp extends Widget {
  const CupertinoApp({super.key, Widget? home, bool? useInheritedMediaQuery});
}

class WidgetsApp extends Widget {
  const WidgetsApp({super.key, Widget? home, bool? useInheritedMediaQuery});
}

// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: avoid_removed_render_object_element_methods
// Source: lib/src/rules/config/migration_rules.dart
// package:flutter/ — rule requires this substring; types from ../flutter_mocks.dart

import '../flutter_mocks.dart';

class _BadRoe extends RenderObjectElement {
  // BAD: removed name (Flutter 3.0) — use insertRenderObjectChild
  // expect_lint: avoid_removed_render_object_element_methods
  void insertChildRenderObject(RenderObject child, Object? slot) {}
}

// GOOD: correct API name
class _GoodRoe extends RenderObjectElement {
  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {}
}

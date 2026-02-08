// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// Test fixture for: require_deep_link_fallback
// Source: lib\src\rules\navigation_rules.dart

import '../flutter_mocks.dart';

final context = BuildContext();
final id = '1';

// BAD: Should trigger require_deep_link_fallback
// expect_lint: require_deep_link_fallback
void _bad505_handleDeepLink(Uri uri) {
  final productId = uri.pathSegments[1];
  Navigator.push(context, ProductPage(id: productId));
}

// GOOD: Should NOT trigger require_deep_link_fallback
void _good505_handleDeepLink(Uri uri) async {
  final productId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
  if (productId == null) {
    Navigator.pushReplacement(context, NotFoundPage());
    return;
  }
  final product = await productService.getProduct(productId);
  if (product == null) {
    Navigator.pushReplacement(context, NotFoundPage());
    return;
  }
  Navigator.push(context, ProductPage(product: product));
}

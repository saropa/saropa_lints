import 'package:flutter/material.dart';

// ignore_for_file: unused_element, unused_local_variable

// BAD: Deep link handler without fallback for missing content
class BadDeepLinkHandler {
  void handleProductDeepLink(BuildContext context, Uri uri) {
    // LINT: No fallback if product is not found
    final productId = uri.pathSegments[1];
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductPage(id: productId)),
    );
  }

  Future<void> handleUserProfileLink(
      BuildContext context, String userId) async {
    // LINT: No fallback if user doesn't exist
    final user = await fetchUser(userId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
    );
  }
}

// GOOD: Deep link handler with proper fallback
class GoodDeepLinkHandler {
  void handleProductDeepLink(BuildContext context, Uri uri) {
    final productId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;

    if (productId == null) {
      // Fallback for invalid URI
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NotFoundPage()),
      );
      return;
    }

    // Additional validation would check if product exists
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductPage(id: productId)),
    );
  }

  Future<void> handleUserProfileLink(
      BuildContext context, String userId) async {
    final user = await fetchUser(userId);

    if (user == null) {
      // Fallback for missing user
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NotFoundPage()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
    );
  }
}

// FALSE POSITIVE TEST: Utility methods managing state should NOT trigger
class DeepLinkStateManager {
  Uri? _initialUri;
  Uri? _currentUri;
  final String _url = 'https://example.com';

  // OK: Simple getter returning a field - not a handler
  Uri? get initialUri => _initialUri;

  // OK: Simple getter returning a field - not a handler
  Uri? get currentRouteUri => _currentUri;

  // OK: Lazy-loading pattern - not a handler
  Uri? get uri => _initialUri ??= Uri.parse(_url);

  // OK: Simple method invocation on a field - not a handler
  Uri? get parsedUri => _url.toUri();

  // OK: Null-aware method invocation - not a handler
  Uri? get safeUri => _url.toUriSafe();

  // OK: Null-aware property access - not a handler
  String? get uriScheme => _initialUri?.scheme;

  // OK: Reset utility method - not a handler
  void resetInitialUri() {
    _initialUri = null;
  }

  // OK: Clear utility method - not a handler
  void clearCurrentUri() {
    _currentUri = null;
  }

  // OK: Set utility method - not a handler
  void setInitialUri(Uri? uri) {
    _initialUri = uri;
  }

  // OK: Get utility method with block body returning field - not a handler
  Uri? getStoredUri() {
    return _initialUri;
  }

  // OK: Get utility method with expression body - not a handler
  Uri? getCachedUri() => _currentUri;

  // OK: Method returning null - trivial accessor
  Uri? getDefaultUri() {
    return null;
  }
}

// FALSE POSITIVE TEST: Utility getters should NOT trigger
extension UriExtensions on Uri? {
  // OK: Utility getter checking URI state
  bool get isNotUriNullOrEmpty => this != null && this.toString().isNotEmpty;

  // OK: Boolean check helper
  bool get hasValidScheme => this?.scheme == 'https';

  // OK: Simple validation
  bool get isUriEmpty => this == null || this.toString().isEmpty;

  // OK: Null check utility
  bool get isUriNull => this == null;

  // OK: Combined nullable check
  bool get isUriNullable => this == null;

  // OK: Validity checker
  bool get isValidDeepLink => this != null && this!.pathSegments.isNotEmpty;

  // OK: Has prefix checker
  bool get hasDeepLinkPrefix => this?.scheme == 'myapp';

  // OK: Check utility
  bool get checkDeepLinkFormat => this?.host == 'example.com';
}

// Mock classes
class ProductPage extends StatelessWidget {
  final String id;
  const ProductPage({required this.id});

  @override
  Widget build(BuildContext context) => Container();
}

class ProfilePage extends StatelessWidget {
  final dynamic user;
  const ProfilePage({required this.user});

  @override
  Widget build(BuildContext context) => Container();
}

class NotFoundPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('Page not found')),
      );
}

Future<dynamic> fetchUser(String userId) async {
  return null;
}

// Mock extension for URI conversion
extension StringToUri on String {
  Uri? toUri() => Uri.tryParse(this);
  Uri? toUriSafe() => Uri.tryParse(this);
}

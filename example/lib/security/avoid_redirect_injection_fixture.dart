// ignore_for_file: unused_local_variable, unused_element
// Test fixture for avoid_redirect_injection rule

import '../flutter_mocks.dart';

// =========================================================================
// avoid_redirect_injection
// =========================================================================
// Warns when redirect URL is used without domain validation.

// Mock types for testing
class AppGridMenuItem {
  final String destination;
  const AppGridMenuItem(this.destination);
}

class NavigationItem {
  final String targetUrl;
  const NavigationItem(this.targetUrl);
}

// BAD: Redirect URL from parameter without validation
void badRedirectFromParameter(String redirectUrl) {
  // expect_lint: avoid_redirect_injection
  Navigator.of(BuildContext()).pushNamed(redirectUrl);
}

// BAD: Simple push with redirect parameter
void badSimplePush(String returnUrl) {
  // expect_lint: avoid_redirect_injection
  push(returnUrl);
}

void push(String route) {}

// BAD: Variable named with redirect term
void badRedirectVariable() {
  const String destination = 'https://evil.com';
  // expect_lint: avoid_redirect_injection
  Navigator.of(BuildContext()).pushNamed(destination);
}

// GOOD: Property access on typed object (should NOT trigger - fixed false positive)
void goodTypedObjectProperty(AppGridMenuItem item) {
  // This should NOT trigger - item.destination is a property on a typed object
  Navigator.of(BuildContext()).pushNamed(item.destination);
}

// GOOD: Property access on another typed object
void goodNavigationItemProperty(NavigationItem item) {
  // This should NOT trigger - item.targetUrl is on a typed object
  Navigator.of(BuildContext()).go(item.targetUrl);
}

// GOOD: Redirect with domain validation
void goodRedirectWithValidation(String redirectUrl) {
  final uri = Uri.parse(redirectUrl);
  final trustedDomains = ['example.com', 'myapp.com'];
  if (!trustedDomains.contains(uri.host)) {
    throw Exception('Untrusted redirect domain');
  }
  Navigator.of(BuildContext()).pushNamed(redirectUrl);
}

// GOOD: Redirect with allowlist check
void goodRedirectWithAllowlist(String returnUrl) {
  // Has allowlist check in block
  if (!_isAllowlistedDomain(returnUrl)) return;
  Navigator.of(BuildContext()).pushNamed(returnUrl);
}

bool _isAllowlistedDomain(String url) => true;

// GOOD: Static route (not from parameter)
void goodStaticRoute() {
  Navigator.of(BuildContext()).pushNamed('/home');
}

// GOOD: Lambda with typed object property access
class GoodLambdaWidget extends StatelessWidget {
  final List<AppGridMenuItem> items;
  const GoodLambdaWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        return GestureDetector(
          onTap: () {
            // Should NOT trigger - item.destination is property access
            Navigator.of(context).pushNamed(item.destination);
          },
          child: Text(item.destination),
        );
      }).toList(),
    );
  }
}

// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_apple_signin_nonce` lint rule.

// NOTE: require_apple_signin_nonce requires specific framework types
// and widget/package context to trigger.
// See rule documentation for bad/good examples.

void main() {}

// GOOD: `SignInWithApple.getAppleIDCredential(scopes: const [])` only fetches
// a one-time authorization code (token revocation); no nonce needed.
// BAD: `getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email])`
// without `nonce:`.

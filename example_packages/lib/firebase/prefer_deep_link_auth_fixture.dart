// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_deep_link_auth` lint rule.

// BAD: Deep link without auth check
// expect_lint: prefer_deep_link_auth
void bad(Uri link) { /* navigate(link); */ }

// GOOD: Verify auth before handling deep link
void good(Uri link) { /* if (isAuthenticated) navigate(link); */ }

void main() {}

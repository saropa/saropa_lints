// ignore_for_file: unused_element, unused_local_variable, depend_on_referenced_packages
// Fixture for require_ssl_pinning_sensitive rule.
// Pattern: rule flags post/put/patch to URLs containing /auth, /login, /token when no pinning package.

// ============ BAD: POST to auth URL without pinning (should trigger) ============

// LINT: require_ssl_pinning_sensitive
Future<void> loginBad(dynamic http, String email, String password) async {
  await http.post(
    Uri.parse('https://api.example.com/auth/login'),
    body: {'email': email, 'password': password},
  );
}

// ============ GOOD: GET to same URL (method is get, not post) — may or may not trigger per rule ============

Future<void> fetchAuthConfigGood(dynamic http) async {
  await http.get(Uri.parse('https://api.example.com/auth/config'));
}

// ============ GOOD: localhost suppressed (should NOT trigger) ============

Future<void> loginLocalhost(dynamic http) async {
  await http.post(
    Uri.parse('http://localhost:8080/auth/login'),
    body: {},
  );
}

// ignore_for_file: unused_element, depend_on_referenced_packages
// Fixture for require_late_access_check rule.

// ============ BAD: late field set in method, read in another (should trigger) ============

// LINT: require_late_access_check
class AuthServiceBad {
  late String _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> getHeaders() {
    return {'Authorization': 'Bearer $_token'};
  }
}

// ============ GOOD: nullable + null check (should NOT trigger) ============

class AuthServiceGoodNullable {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> getHeaders() {
    final token = _token;
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }
}

// ============ GOOD: late but only assigned in constructor (should NOT trigger) ============

class AuthServiceGoodConstructor {
  late final String _token;

  AuthServiceGoodConstructor(String token) : _token = token;

  Map<String, String> getHeaders() {
    return {'Authorization': 'Bearer $_token'};
  }
}

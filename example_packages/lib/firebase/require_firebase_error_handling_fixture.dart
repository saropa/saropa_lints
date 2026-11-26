// ignore_for_file: unused_local_variable, unused_element
// Fixture for require_firebase_error_handling.
// Rule: an awaited Firebase call needs a try-catch or .catchError — at the
// call itself, or (for a library-private async helper) at EVERY caller.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: awaited Firebase call with no error handling — should trigger.
Future<String?> loadTokenUnguarded() async {
  // expect_lint: require_firebase_error_handling
  return await FirebaseMessaging.instance.getToken();
}

// GOOD: the call itself is inside try-catch — should NOT trigger.
Future<String?> loadTokenGuarded() async {
  try {
    return await FirebaseMessaging.instance.getToken();
  } on Object catch (e) {
    return null;
  }
}

class _TokenPolicy {
  // GOOD: private helper whose every caller in this library awaits it
  // inside try-catch — the handling lives at the call sites.
  static Future<String?> _readToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  static Future<String?> refresh() async {
    try {
      return await _readToken();
    } on Object catch (e) {
      return null;
    }
  }
}

class _PermissionPolicy {
  // BAD: private helper with one unguarded caller (`requestUnguarded`), so
  // the helper's own call is still unhandled on that path.
  static Future<dynamic> _request() async {
    // expect_lint: require_firebase_error_handling
    return await FirebaseMessaging.instance.requestPermission();
  }

  static Future<dynamic> requestGuarded() async {
    try {
      return await _request();
    } on Object catch (e) {
      return null;
    }
  }

  static Future<dynamic> requestUnguarded() async {
    return await _request();
  }
}

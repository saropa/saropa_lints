// ignore_for_file: unused_local_variable, unused_element
// Test fixtures for OWASP Coverage Gap Rules (v3.2.0)

import 'dart:convert';
import 'dart:io';

// =============================================================================
// avoid_ignoring_ssl_errors
// =============================================================================

void testAvoidIgnoringSslErrors() {
  // BAD: Unconditionally returning true bypasses SSL validation
  // expect_lint: avoid_ignoring_ssl_errors
  final client = HttpClient()
    ..badCertificateCallback = (cert, host, port) => true;

  // BAD: Arrow function returning true
  // expect_lint: avoid_ignoring_ssl_errors
  final client2 = HttpClient()..badCertificateCallback = (_, __, ___) => true;

  // GOOD: Proper certificate validation
  final goodClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) {
      // Validate against pinned certificate
      return host == 'trusted.example.com';
    };
}

// =============================================================================
// require_https_only
// =============================================================================

void testRequireHttpsOnly() {
  // BAD: HTTP URLs are insecure
  // expect_lint: require_https_only
  const apiUrl = 'http://api.example.com/v1';

  // expect_lint: require_https_only
  final endpoint = 'http://insecure.example.com/data';

  // GOOD: HTTPS URLs are secure
  const secureUrl = 'https://api.example.com/v1';

  // GOOD: Localhost is allowed for development
  const devUrl = 'http://localhost:3000';
  const devUrl2 = 'http://127.0.0.1:8080';
  const emulatorUrl = 'http://10.0.2.2:5000';
}

// =============================================================================
// avoid_unsafe_deserialization
// =============================================================================

void testAvoidUnsafeDeserialization() {
  // Note: This rule only triggers when jsonDecode result is used
  // in dangerous operations like execute/eval/run/command

  // BAD: JSON data used in dangerous operation without type checking
  void badExample(String response) {
    final data = jsonDecode(response);
    // expect_lint: avoid_unsafe_deserialization
    _executeCommand(data['command']);
  }

  // GOOD: Type validation before use
  void goodExample(String response) {
    final data = jsonDecode(response);
    if (data case {'command': String cmd}) {
      // Type-safe usage
      print(cmd);
    }
  }

  // GOOD: Using model class
  void goodExample2(String response) {
    final user = User.fromJson(jsonDecode(response));
    print(user.name);
  }
}

void _executeCommand(dynamic cmd) {}

class User {
  final String name;
  User({required this.name});
  factory User.fromJson(Map<String, dynamic> json) => User(name: json['name']);
}

// =============================================================================
// avoid_user_controlled_urls
// =============================================================================

class _TextEditingController {
  String text = '';
}

class _HttpClient {
  Future<void> get(dynamic uri) async {}
}

void testAvoidUserControlledUrls() async {
  final textController = _TextEditingController();
  final httpClient = _HttpClient();

  // BAD: User input directly in HTTP request
  // expect_lint: avoid_user_controlled_urls
  await httpClient.get(Uri.parse(textController.text));

  // GOOD: Validate URL before use
  final userInput = textController.text;
  final uri = Uri.parse(userInput);
  if (uri.scheme == 'https' && _allowedHosts.contains(uri.host)) {
    await httpClient.get(uri);
  }
}

const _allowedHosts = ['api.example.com'];

// =============================================================================
// require_catch_logging
// =============================================================================

void testRequireCatchLogging() async {
  // BAD: Empty catch block
  try {
    await _riskyOperation();
    // expect_lint: require_catch_logging
  } catch (e) {
    // Silent catch - security events go unlogged!
  }

  // BAD: Catch without logging
  try {
    await _riskyOperation();
    // expect_lint: require_catch_logging
  } catch (e) {
    _showError('Something went wrong'); // No logging!
  }

  // GOOD: Logging the exception
  try {
    await _riskyOperation();
  } catch (e, stackTrace) {
    print('Error occurred: $e, $stackTrace');
    rethrow;
  }

  // GOOD: Rethrowing
  try {
    await _riskyOperation();
  } catch (e) {
    rethrow;
  }

  // GOOD: Using logger
  try {
    await _riskyOperation();
  } catch (e) {
    _logger.error('Operation failed', e);
  }
}

Future<void> _riskyOperation() async {}
void _showError(String msg) {}

class _Logger {
  void error(String msg, dynamic e) {}
}

final _logger = _Logger();

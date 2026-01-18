// ignore_for_file: avoid_print, unused_local_variable, unused_element
// ignore_for_file: unused_field, prefer_const_declarations

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// =============================================================================
// v4.1.6 Test Fixtures - Logging Rules
// =============================================================================

// BAD: print without kDebugMode check
void testPrintInRelease() {
  // expect_lint: avoid_print_in_release
  print('This runs in release builds!');
}

// GOOD: print with kDebugMode check
void testPrintWithDebugMode() {
  if (kDebugMode) {
    print('Only runs in debug mode');
  }
}

// BAD: String concatenation in logs
void testStructuredLogging(String user, DateTime time) {
  // expect_lint: require_structured_logging
  print('User ' + user + ' logged in at ' + time.toString());
}

// GOOD: String interpolation instead
void testGoodLogging(String user, DateTime time) {
  if (kDebugMode) {
    print('User $user logged in at $time');
  }
}

// BAD: Sensitive data in logs
void testSensitiveInLogs(String password, String apiKey) {
  // expect_lint: avoid_sensitive_in_logs
  print('Login with password: $password');

  // expect_lint: avoid_sensitive_in_logs
  debugPrint('Using API key: $apiKey');
}

// GOOD: No sensitive data in logs
void testGoodSecureLogs(String userId) {
  if (kDebugMode) {
    print('Login attempt for user: $userId');
  }
}

// =============================================================================
// v4.1.6 Test Fixtures - Platform Rules
// =============================================================================

// BAD: Platform-specific API without platform check
void testPlatformCheck() {
  // expect_lint: require_platform_check
  final file = File('data.txt');
  file.writeAsStringSync('Hello');
}

// GOOD: Platform-specific API with platform check
void testGoodPlatformCheck() {
  if (!kIsWeb) {
    final file = File('data.txt');
    file.writeAsStringSync('Hello');
  }
}

// BAD: Platform.isX without kIsWeb guard
void testPlatformIoConditional() {
  // expect_lint: prefer_platform_io_conditional
  if (Platform.isAndroid) {
    // Android code
  }
}

// GOOD: Platform.isX with kIsWeb guard
void testGoodPlatformIoConditional() {
  if (!kIsWeb && Platform.isAndroid) {
    // Android code
  }
}

// NOTE: avoid_web_only_dependencies is tested via import statements
// which would cause compile errors in this file

// BAD: Platform.isX in build method (widget context)
class BadPlatformWidget extends StatelessWidget {
  const BadPlatformWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: prefer_foundation_platform_check
    if (Platform.isIOS) {
      return const Text('iOS');
    }
    return const Text('Other');
  }
}

// GOOD: defaultTargetPlatform in build method
class GoodPlatformWidget extends StatelessWidget {
  const GoodPlatformWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const Text('iOS');
    }
    return const Text('Other');
  }
}

// =============================================================================
// v4.1.6 Test Fixtures - JSON/API Rules
// =============================================================================

// BAD: DateTime.parse with variable (non-literal)
void testDateFormatSpecification(Map<String, dynamic> json) {
  // expect_lint: require_date_format_specification
  final date = DateTime.parse(json['created_at'] as String);
}

// GOOD: DateTime.tryParse for safety
void testGoodDateParsing(Map<String, dynamic> json) {
  final date = DateTime.tryParse(json['created_at'] as String);
}

// BAD: Non-ISO date format
void testIso8601Dates(DateTime date) {
  // expect_lint: prefer_iso8601_dates
  final formatted = DateFormat('MM/dd/yyyy').format(date);
}

// GOOD: ISO 8601 format
void testGoodDateFormat(DateTime date) {
  final formatted = date.toIso8601String();
}

// BAD: Chained JSON access without null safety
void testOptionalFieldCrash(Map<String, dynamic> json) {
  // expect_lint: avoid_optional_field_crash
  final name = json['user']['name'];
}

// GOOD: Null-aware chained access
void testGoodJsonAccess(Map<String, dynamic> json) {
  final name = json['user']?['name'];
}

// BAD: Manual JSON key mapping (3+ mappings)
class User {
  final String userName;
  final String emailAddress;
  final int userAge;

  User({
    required this.userName,
    required this.emailAddress,
    required this.userAge,
  });

  // expect_lint: prefer_explicit_json_keys
  factory User.fromJson(Map<String, dynamic> json) => User(
        userName: json['user_name'] as String,
        emailAddress: json['email'] as String,
        userAge: json['age'] as int,
      );
}

// =============================================================================
// v4.1.6 Test Fixtures - Configuration Rules
// =============================================================================

// BAD: Hardcoded config values
class BadConfig {
  // expect_lint: avoid_hardcoded_config
  static const apiUrl = 'https://api.example.com/v1';

  // expect_lint: avoid_hardcoded_config
  static const apiKey = 'sk_live_abc123def456';
}

// GOOD: Environment-based config
class GoodConfig {
  static const apiUrl = String.fromEnvironment('API_URL');
  static const apiKey = String.fromEnvironment('API_KEY');
}

// BAD: Mixed production/development config
class MixedConfig {
  // expect_lint: avoid_mixed_environments
  static const apiUrl = 'https://api.prod.example.com'; // Production!
  static const debug = true; // But debug mode!
  static const testMode = false;
}

// GOOD: Conditional config
class ConsistentConfig {
  static const apiUrl = kReleaseMode
      ? 'https://api.prod.example.com'
      : 'https://api.dev.example.com';
  static const debug = !kReleaseMode;
}

// =============================================================================
// v4.1.6 Test Fixtures - Lifecycle Rules
// =============================================================================

// BAD: Late field initialized in build()
class BadLateInitWidget extends StatefulWidget {
  const BadLateInitWidget({super.key});

  @override
  State<BadLateInitWidget> createState() => _BadLateInitWidgetState();
}

class _BadLateInitWidgetState extends State<BadLateInitWidget> {
  late TextEditingController _controller;

  // expect_lint: require_late_initialization_in_init_state
  @override
  Widget build(BuildContext context) {
    _controller = TextEditingController(); // Wrong! Recreated on every build!
    return TextField(controller: _controller);
  }
}

// GOOD: Late field initialized in initState()
class GoodLateInitWidget extends StatefulWidget {
  const GoodLateInitWidget({super.key});

  @override
  State<GoodLateInitWidget> createState() => _GoodLateInitWidgetState();
}

class _GoodLateInitWidgetState extends State<GoodLateInitWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(); // Correct!
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}

// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: avoid_print, avoid_print_in_production, avoid_logging_sensitive_data
// Test fixture for JSON and DateTime rules

import 'dart:convert';

// =========================================================================
// require_json_decode_try_catch
// =========================================================================

void badJsonDecode(String jsonString) {
  // expect_lint: require_json_decode_try_catch
  final data = jsonDecode(jsonString);
}

void goodJsonDecode(String jsonString) {
  // GOOD: Wrapped in try-catch
  try {
    final data = jsonDecode(jsonString);
  } on FormatException catch (e) {
    print('Invalid JSON: $e');
  }
}

// =========================================================================
// avoid_datetime_parse_unvalidated
// =========================================================================

void badDateTimeParse(String dateString) {
  // expect_lint: avoid_datetime_parse_unvalidated
  final date = DateTime.parse(dateString);
}

void goodDateTimeParse(String dateString) {
  // GOOD: Use tryParse
  final date = DateTime.tryParse(dateString);
  if (date == null) {
    print('Invalid date');
  }
}

void goodDateTimeParseWithTryCatch(String dateString) {
  // GOOD: Wrapped in try-catch
  try {
    final date = DateTime.parse(dateString);
  } on FormatException {
    print('Invalid date');
  }
}

// =========================================================================
// prefer_try_parse_for_dynamic_data
// =========================================================================

void badIntParse(String userInput) {
  // expect_lint: prefer_try_parse_for_dynamic_data
  final age = int.parse(userInput);
}

void badDoubleParse(String priceString) {
  // expect_lint: prefer_try_parse_for_dynamic_data
  final price = double.parse(priceString);
}

void badNumParse(String value) {
  // expect_lint: prefer_try_parse_for_dynamic_data
  final number = num.parse(value);
}

void goodIntTryParse(String userInput) {
  // GOOD: Use tryParse with null handling
  final age = int.tryParse(userInput) ?? 0;
}

void goodDoubleTryParse(String priceString) {
  // GOOD: Use tryParse with null handling
  final price = double.tryParse(priceString) ?? 0.0;
}

void goodNumTryParse(String value) {
  // GOOD: Use tryParse with null handling
  final number = num.tryParse(value) ?? 0;
}

void goodIntParseInTryCatch(String userInput) {
  // GOOD: Wrapped in try-catch
  try {
    final age = int.parse(userInput);
  } on FormatException {
    print('Invalid number');
  }
}

void badUriParse(String url) {
  // expect_lint: prefer_try_parse_for_dynamic_data
  final uri = Uri.parse(url);
}

void goodUriTryParse(String url) {
  // GOOD: Use tryParse with null handling
  final uri = Uri.tryParse(url);
  if (uri == null) {
    print('Invalid URL');
  }
}

// =========================================================================
// avoid_double_for_money
// =========================================================================
// Rule uses WORD-BOUNDARY matching: only flags complete words that are
// unambiguous money terms (price, salary, wage, money, currency, dollar, euro).
// Substring matches like "aud" in "audioVolume" no longer trigger the rule.

class BadMoneyClass {
  // expect_lint: avoid_double_for_money
  double price = 19.99;

  // expect_lint: avoid_double_for_money
  double itemPrice = 9.99;

  // expect_lint: avoid_double_for_money
  double salary = 50000.0;

  // expect_lint: avoid_double_for_money
  double hourlyWage = 15.50;

  // expect_lint: avoid_double_for_money
  double dollarValue = 50.0;

  // expect_lint: avoid_double_for_money
  double euroAmount = 75.0;

  // expect_lint: avoid_double_for_money
  double monthlyMoney = 1000.0;

  // expect_lint: avoid_double_for_money
  double localCurrency = 500.0;
}

class GoodMoneyClass {
  // GOOD: Use int cents
  int priceInCents = 1999;
  int salaryInCents = 5000000;
}

class NotMoneyDoubles {
  // GOOD: Generic terms no longer trigger the lint
  double totalAmount = 0.0; // "total" and "amount" are too generic
  double balance = 100.50; // could be work-life balance
  double cost = 0.0; // could be computational cost
  double fee = 0.0; // could be service fee callback
  double total = 0.0; // too generic
  double amount = 0.0; // too generic
  double payment = 0.0; // could be payment callback
  double discount = 0.0; // too generic
  double revenue = 0.0; // business context varies
  double profit = 0.0; // business context varies
  double budget = 0.0; // could be time budget
  double expense = 0.0; // too generic
  double income = 0.0; // too generic

  // GOOD: Short currency codes removed - too ambiguous
  double usdAmount = 0.0; // could be "used" typo or intentional abbrev
  double cadScore = 0.0; // CAD file format
  double audLevel = 0.0; // audio level

  // GOOD: Substring matches no longer trigger (word-boundary matching)
  double audioVolume = 1.0; // "aud" is part of "audio", not a separate word
  double imageUrlVerticalOffsetPercent = 0.0; // no money words
  double defaultAudioVolume = 0.5; // "aud" substring doesn't match

  // Non-monetary aggregates
  double totalPoints = 0.0;
  double totalSteps = 0.0;
  double totalCalories = 0.0;
  double progressPercent = 0.0;
}

// =========================================================================
// avoid_sensitive_in_logs (alias: avoid_sensitive_data_in_logs)
// =========================================================================

void badLogging(String password, String token) {
  // expect_lint: avoid_sensitive_in_logs
  print('User password: $password');

  // expect_lint: avoid_sensitive_in_logs
  print('Auth token: $token');
}

void goodLogging(String userId) {
  // GOOD: Log non-sensitive data
  print('User logged in: $userId');
}

void goodLoggingNullChecks(Object? credential, String? token) {
  // GOOD: Null checks don't expose sensitive data
  print(
    'Auth ${credential != null ? "succeeded" : "failed (null credential)"}',
  );
  print('Token status: ${token == null ? "missing" : "present"}');
  print('Token length: ${token?.length}');
}

// =========================================================================
// avoid_autoplay_audio
// =========================================================================

// This rule detects autoPlay: true on audio/video players
// Example would be:
// BetterPlayerController(
//   configuration: BetterPlayerConfiguration(
//     autoPlay: true,  // <- This would trigger the lint
//   ),
// );

// =========================================================================
// JSON/API Rules
// =========================================================================

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
  final formatted = DateFormatDemo('MM/dd/yyyy').format(date);
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
class UserJsonDemo {
  final String userName;
  final String emailAddress;
  final int userAge;

  UserJsonDemo({
    required this.userName,
    required this.emailAddress,
    required this.userAge,
  });

  // expect_lint: prefer_explicit_json_keys
  factory UserJsonDemo.fromJson(Map<String, dynamic> json) => UserJsonDemo(
        userName: json['user_name'] as String,
        emailAddress: json['email'] as String,
        userAge: json['age'] as int,
      );
}

// Mock DateFormat
class DateFormatDemo {
  DateFormatDemo(this.pattern, [this.locale]);
  final String pattern;
  final String? locale;
  String format(DateTime date) => '';
}

// =========================================================================
// Configuration Rules
// =========================================================================

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

const bool kReleaseMode = false;

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

class BadMoneyClass {
  // expect_lint: avoid_double_for_money
  double price = 19.99;

  // expect_lint: avoid_double_for_money
  double totalAmount = 0.0;

  // expect_lint: avoid_double_for_money
  double balance = 100.50;
}

class GoodMoneyClass {
  // GOOD: Use int cents
  int priceInCents = 1999;
  int totalAmountInCents = 0;
  int balanceInCents = 10050;
}

class FalsePositiveExclusions {
  // GOOD: These should NOT trigger avoid_double_for_money
  // because they contain false positive patterns
  double?
      imageUrlVerticalOffsetPercent; // "percent" contains "cent" but is not money
  double centerX = 0.0; // "center" contains "cent" but is not money
  double accentColorOpacity = 1.0; // "accent" contains "cent" but is not money
  double recentProgress = 0.0; // "recent" contains "cent" but is not money
  double descentOffset = 0.0; // "descent" contains "cent" but is not money
  double centimeterScale = 1.0; // "centimeter" contains "cent" but is not money
}

// =========================================================================
// avoid_sensitive_data_in_logs
// =========================================================================

void badLogging(String password, String token) {
  // expect_lint: avoid_sensitive_data_in_logs
  print('User password: $password');

  // expect_lint: avoid_sensitive_data_in_logs
  print('Auth token: $token');
}

void goodLogging(String userId) {
  // GOOD: Log non-sensitive data
  print('User logged in: $userId');
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

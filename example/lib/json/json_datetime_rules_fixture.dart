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

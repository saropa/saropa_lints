// ignore_for_file: unused_local_variable, unused_element, always_declare_return_types
// ignore_for_file: prefer_const_constructors, avoid_print

/// Fixture for all six google_sign_in lint rules.
///
/// Mock stubs model the minimal public surface of google_sign_in v6 and v7 APIs.
/// Violation lines are marked `// expect_lint: <rule_name>`.
/// Compliant lines are marked `// OK`.
library;

import 'package:google_sign_in/google_sign_in.dart';

// =============================================================================
// Mock API surface (not real; allows the fixture to be syntactically valid
// without depending on the real package at analysis time)
// =============================================================================

// ignore: avoid_pre_v7_google_sign_in
class GoogleSignIn {
  // v6 constructor (removed in v7)
  GoogleSignIn({List<String>? scopes});

  // v6 sign-in methods (removed in v7)
  Future<GoogleSignInAccount?> signIn() async => null;
  Future<GoogleSignInAccount?> signInSilently() async => null;

  // v7 methods
  Future<void> initialize({String? clientId, String? serverClientId}) async {}
  Future<GoogleSignInAccount> authenticate() async => GoogleSignInAccount();
  Future<GoogleSignInAccount> attemptLightweightAuthentication() async =>
      GoogleSignInAccount();
  Future<bool> supportsAuthenticate() async => true;

  static final GoogleSignIn instance = GoogleSignIn();
}

class GoogleSignInAccount {
  // v6 field — removed/always-null in v7
  String? accessToken;

  // v7 identity token (still valid in v7)
  String? idToken;

  GoogleSignInAuthorizationClient get authorizationClient =>
      GoogleSignInAuthorizationClient();
}

class GoogleSignInAuthorizationClient {
  Future<GoogleSignInClientAuthorization> authorizeScopes(
    List<String> scopes,
  ) async => GoogleSignInClientAuthorization();
}

class GoogleSignInClientAuthorization {
  String accessToken = '';
}

enum GoogleSignInExceptionCode {
  canceled,
  interrupted,
  uiUnavailable,
  clientConfigurationError,
  providerConfigurationError,
  networkError,
  unknown,
}

class GoogleSignInException implements Exception {
  GoogleSignInException(this.code, [this.message]);
  final GoogleSignInExceptionCode code;
  final String? message;
}

// =============================================================================
// avoid_pre_v7_google_sign_in (WARNING)
// Rule fires while project is on google_sign_in < 7.0.0 (pre-upgrade gate).
// =============================================================================

void preV7Bad() {
  // expect_lint: avoid_pre_v7_google_sign_in
  final _gsi = GoogleSignIn(scopes: ['email']);
}

Future<void> preV7BadSignIn() async {
  final _gsi = GoogleSignIn.instance;
  // expect_lint: avoid_pre_v7_google_sign_in
  final account = await _gsi.signIn();
}

Future<void> preV7BadSignInSilently() async {
  final _gsi = GoogleSignIn.instance;
  // expect_lint: avoid_pre_v7_google_sign_in
  final account = await _gsi.signInSilently();
}

Future<void> preV7Good() async {
  // OK: v7 API — uses singleton, initialize(), authenticate().
  await GoogleSignIn.instance.initialize(clientId: 'my-client-id');
  final account = await GoogleSignIn.instance.authenticate();
}

// =============================================================================
// google_sign_in_missing_exception_handler (WARNING)
// =============================================================================

Future<void> missingExceptionHandlerBad() async {
  // expect_lint: google_sign_in_missing_exception_handler
  final account = await GoogleSignIn.instance.authenticate();
}

Future<void> missingExceptionHandlerAttemptBad() async {
  // expect_lint: google_sign_in_missing_exception_handler
  final account =
      await GoogleSignIn.instance.attemptLightweightAuthentication();
}

Future<void> missingExceptionHandlerGood() async {
  // OK: wrapped in try/catch for GoogleSignInException.
  try {
    final account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return;
    print('Error: ${e.message}');
  }
}

Future<void> missingExceptionHandlerGoodBare() async {
  // OK: bare catch covers all exceptions including GoogleSignInException.
  try {
    final account = await GoogleSignIn.instance.authenticate();
  } catch (e) {
    print('Error: $e');
  }
}

// =============================================================================
// google_sign_in_unchecked_supports_authenticate (WARNING)
// =============================================================================

Future<void> uncheckedSupportsAuthenticateBad() async {
  // expect_lint: google_sign_in_unchecked_supports_authenticate
  final account = await GoogleSignIn.instance.authenticate();
}

Future<void> uncheckedSupportsAuthenticateGood() async {
  // OK: guarded by supportsAuthenticate() check.
  if (!await GoogleSignIn.instance.supportsAuthenticate()) {
    return; // Use GoogleSignInButton on web.
  }
  try {
    final account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return;
  }
}

// =============================================================================
// google_sign_in_auth_token_from_authenticate (ERROR)
// =============================================================================

Future<void> authTokenBad() async {
  final account = await GoogleSignIn.instance.authenticate();
  // expect_lint: google_sign_in_auth_token_from_authenticate
  final token = account.accessToken; // null in v7 — silent data bug
}

Future<void> authTokenGood() async {
  final account = await GoogleSignIn.instance.authenticate();
  // OK: idToken is still valid in v7 for identity purposes.
  final idToken = account.idToken;

  // OK: uses the authorization client for access tokens.
  final authorization = await account.authorizationClient.authorizeScopes([
    'https://www.googleapis.com/auth/calendar',
  ]);
  final accessToken = authorization.accessToken;
}

// =============================================================================
// google_sign_in_canceled_not_handled (INFO)
// =============================================================================

Future<void> canceledNotHandledBad() async {
  try {
    final account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (e) {
    // expect_lint: google_sign_in_canceled_not_handled
    // All exception codes treated the same — cancellation shows an error.
    print('Sign-in failed: ${e.message}');
  }
}

Future<void> canceledNotHandledGoodWithCode() async {
  try {
    final account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (e) {
    // OK: handles cancellation explicitly.
    if (e.code == GoogleSignInExceptionCode.canceled) return;
    print('Sign-in failed: ${e.message}');
  }
}

Future<void> canceledNotHandledGoodRethrow() async {
  try {
    final account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (_) {
    // OK: re-throws so caller handles cancellation.
    rethrow;
  }
}

// =============================================================================
// google_sign_in_authenticate_before_initialize (WARNING)
// =============================================================================

Future<void> authenticateBeforeInitializeBad() async {
  // expect_lint: google_sign_in_authenticate_before_initialize
  // No prior await initialize() in this function body.
  final account = await GoogleSignIn.instance.authenticate();
}

Future<void> authenticateBeforeInitializeGood() async {
  // OK: initialize() is awaited before authenticate().
  await GoogleSignIn.instance.initialize(clientId: 'my-client-id');
  try {
    final account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return;
  }
}

Future<void> authenticateBeforeInitializeGoodCallback() async {
  // OK: authenticate() is inside a .then() callback — ordering is structural.
  GoogleSignIn.instance.initialize().then((_) async {
    final account = await GoogleSignIn.instance.authenticate();
  });
}

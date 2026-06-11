// ignore_for_file: unused_local_variable, unused_element, dead_code
// ignore_for_file: always_declare_return_types

/// Test fixtures for sign_in_with_apple lint rules.
///
/// BAD patterns are marked with `// LINT: <rule_name>`.
/// GOOD patterns are marked with `// OK`.
library;

import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// =============================================================================
// Mock stubs for the sign_in_with_apple surface used by the fixture.
// These are here only because the example_packages tree is excluded from
// analysis and the package itself is not in the example pubspec.
// =============================================================================

// ignore_for_file: avoid_classes_with_only_static_members
class SignInWithApple {
  static Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<dynamic> scopes,
    String? nonce,
  }) async =>
      throw UnimplementedError();

  static Future<bool> isAvailable() async => true;

  static Future<CredentialState> getCredentialState(
    String userIdentifier,
  ) async =>
      CredentialState.authorized;
}

class AuthorizationCredentialAppleID {
  final String? identityToken;
  final String? givenName;
  final String? familyName;
  final String? email;
  final String authorizationCode;
  AuthorizationCredentialAppleID({
    this.identityToken,
    this.givenName,
    this.familyName,
    this.email,
    required this.authorizationCode,
  });
}

class SignInWithAppleAuthorizationException implements Exception {
  final AuthorizationErrorCode code;
  final String message;
  const SignInWithAppleAuthorizationException({
    required this.code,
    required this.message,
  });
}

enum AuthorizationErrorCode { canceled, failed, invalidResponse, unknown }

enum AppleIDAuthorizationScopes { email, fullName }

enum CredentialState { authorized, revoked, notFound }

// =============================================================================
// Fixtures: apple_sign_in_unhandled_authorization_exception
// =============================================================================

// BAD: getAppleIDCredential with no enclosing try/catch.
Future<void> badNoTryCatch() async {
  // LINT: apple_sign_in_unhandled_authorization_exception
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email],
  );
  print(credential.authorizationCode);
}

// BAD: wrapped in try but no catch that covers the SIWA exception.
Future<void> badWrongCatchType() async {
  try {
    // LINT: apple_sign_in_unhandled_authorization_exception
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    print(credential.authorizationCode);
  } on FormatException catch (_) {
    // Wrong exception type — SIWA exceptions propagate uncaught.
  }
}

// GOOD: bare catch (covers everything).
Future<void> goodBareCatch() async {
  try {
    // OK
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    print(credential.authorizationCode);
  } catch (_) {}
}

// GOOD: named SIWA exception type.
Future<void> goodSiwaCatch() async {
  try {
    // OK
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    print(credential.authorizationCode);
  } on SignInWithAppleAuthorizationException catch (_) {}
}

// GOOD: broad Object catch.
Future<void> goodObjectCatch() async {
  try {
    // OK
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    print(credential.authorizationCode);
  } on Object catch (_) {}
}

// =============================================================================
// Fixtures: apple_sign_in_unhandled_cancel
// =============================================================================

// BAD: catches SignInWithAppleAuthorizationException but ignores .canceled.
Future<void> badNoCanceledCheck() async {
  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    print(credential.authorizationCode);
    // LINT: apple_sign_in_unhandled_cancel
  } on SignInWithAppleAuthorizationException catch (e) {
    // Treats all errors the same — user cancel shows an error dialog.
    print('Error: ${e.message}');
  }
}

// GOOD: explicitly handles the canceled code.
Future<void> goodCanceledCheck() async {
  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    print(credential.authorizationCode);
  } on SignInWithAppleAuthorizationException catch (e) {
    // OK: cancel is handled silently.
    if (e.code == AuthorizationErrorCode.canceled) return;
    print('Error: ${e.message}');
  }
}

// =============================================================================
// Fixtures: apple_sign_in_unchecked_availability
// =============================================================================

// BAD: calls getAppleIDCredential with no isAvailable guard in the file.
// (No isAvailable call anywhere in the section below.)
Future<void> badNoAvailabilityCheck() async {
  // LINT: apple_sign_in_unchecked_availability
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email],
  );
  print(credential.authorizationCode);
}

// GOOD: isAvailable() appears in the same file (above or alongside the call).
Future<void> goodWithAvailabilityCheck() async {
  final available = await SignInWithApple.isAvailable();
  if (!available) return;
  // OK: isAvailable() is present in this file.
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email],
  );
  print(credential.authorizationCode);
}

// =============================================================================
// Fixtures: apple_sign_in_null_identity_token
// =============================================================================

Future<void> badIdentityTokenAssignment(
  AuthorizationCredentialAppleID credential,
) async {
  // LINT: apple_sign_in_null_identity_token
  // ignore: invalid_assignment
  String token = credential.identityToken; // String? → String
  print(token);
}

// GOOD: type is inferred (String?) — no forced non-nullable assignment.
Future<void> goodIdentityTokenInferred(
  AuthorizationCredentialAppleID credential,
) async {
  // OK: inferred as String?
  final token = credential.identityToken;
  if (token == null) return;
  print(token);
}

// GOOD: explicitly typed as String? — null-safe.
Future<void> goodIdentityTokenNullable(
  AuthorizationCredentialAppleID credential,
) async {
  // OK: explicitly nullable
  String? token = credential.identityToken;
  print(token);
}

// =============================================================================
// Fixtures: apple_sign_in_relying_on_name_email
// =============================================================================

Future<void> badNameEmailAssignment(
  AuthorizationCredentialAppleID credential,
) async {
  // LINT: apple_sign_in_relying_on_name_email
  // ignore: invalid_assignment
  String name = credential.givenName; // null on every sign-in after first
  // LINT: apple_sign_in_relying_on_name_email
  // ignore: invalid_assignment
  String mail = credential.email; // same
  print('$name $mail');
}

// GOOD: null-safe access with ??.
Future<void> goodNameEmailWithFallback(
  AuthorizationCredentialAppleID credential,
  String storedName,
) async {
  // OK: fallback via ??
  final name = credential.givenName ?? storedName;
  // OK: inferred String?
  final mail = credential.email;
  print('$name $mail');
}

// GOOD: typed String? — no crash.
Future<void> goodNameEmailNullable(
  AuthorizationCredentialAppleID credential,
) async {
  // OK
  String? name = credential.givenName;
  String? mail = credential.email;
  print('$name $mail');
}

// =============================================================================
// Fixtures: apple_sign_in_unchecked_credential_state
// =============================================================================

Future<void> badCredentialStateDiscarded(String userId) async {
  // LINT: apple_sign_in_unchecked_credential_state
  await SignInWithApple.getCredentialState(userId); // result discarded
}

// GOOD: result is stored and acted on.
Future<void> goodCredentialStateChecked(String userId) async {
  // OK
  final state = await SignInWithApple.getCredentialState(userId);
  if (state == CredentialState.revoked) {
    // sign out
  }
}

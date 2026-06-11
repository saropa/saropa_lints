// ignore_for_file: unused_local_variable, unused_element, deprecated_member_use

/// Fixtures for the 4 local_auth_3 migration rules.
///
/// These symbols only exist in local_auth 2.x (the `AuthenticationOptions`
/// class and `PlatformException`-based throw contract were removed in 3.0).
/// The fixture is compiled against a 2.x mock so the AST shapes that the
/// migration rules detect are actually present.
///
/// Rules covered:
///   - local_auth_deprecated_options_class
///   - local_auth_use_error_dialogs_removed
///   - local_auth_sticky_auth_renamed
///   - local_auth_platform_exception_catch
library;

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

// ---------------------------------------------------------------------------
// Mock stubs for 2.x symbols (do not exist in 3.x).
// Used so this fixture compiles without a real local_auth 2.x dependency.
// ---------------------------------------------------------------------------

/// Stub representing `AuthenticationOptions` as it existed in local_auth 2.x.
class AuthenticationOptions {
  const AuthenticationOptions({
    this.biometricOnly = false,
    this.sensitiveTransaction = true,
    this.stickyAuth = false,
    this.useErrorDialogs = true,
  });
  final bool biometricOnly;
  final bool sensitiveTransaction;
  final bool stickyAuth;
  final bool useErrorDialogs;
}

// ---------------------------------------------------------------------------
// local_auth_deprecated_options_class
// ---------------------------------------------------------------------------

final _auth = LocalAuthentication();

/// BAD: AuthenticationOptions is removed in 3.0.
Future<void> badDeprecatedOptionsClass() async {
  // expect_lint: local_auth_deprecated_options_class
  final options = AuthenticationOptions(biometricOnly: true);
  if (await _auth.authenticate(localizedReason: 'Unlock')) {}
}

/// GOOD: pass fields directly to authenticate().
Future<void> goodDeprecatedOptionsClass() async {
  if (await _auth.authenticate(
    localizedReason: 'Unlock',
    biometricOnly: true,
  )) {}
}

// ---------------------------------------------------------------------------
// local_auth_use_error_dialogs_removed
// ---------------------------------------------------------------------------

/// BAD: useErrorDialogs was removed in 3.0; no platform replacement exists.
Future<void> badUseErrorDialogs() async {
  // expect_lint: local_auth_deprecated_options_class
  // expect_lint: local_auth_use_error_dialogs_removed
  final options = AuthenticationOptions(
    useErrorDialogs: false,
    biometricOnly: true,
  );
  if (await _auth.authenticate(localizedReason: 'Pay')) {}
}

/// GOOD: build your own error UI in the catch handler; no useErrorDialogs.
Future<void> goodUseErrorDialogs() async {
  try {
    if (await _auth.authenticate(localizedReason: 'Pay', biometricOnly: true)) {}
  } on LocalAuthException catch (e) {
    // Show custom error UI here.
    _showError(e);
  }
}

// ---------------------------------------------------------------------------
// local_auth_sticky_auth_renamed
// ---------------------------------------------------------------------------

/// BAD: stickyAuth was renamed to persistAcrossBackgrounding in 3.0.
Future<void> badStickyAuthRenamed() async {
  // expect_lint: local_auth_deprecated_options_class
  // expect_lint: local_auth_sticky_auth_renamed
  final options = AuthenticationOptions(
    stickyAuth: true,
    biometricOnly: true,
  );
  if (await _auth.authenticate(localizedReason: 'Unlock')) {}
}

/// GOOD: use the renamed parameter directly on authenticate().
Future<void> goodStickyAuthRenamed() async {
  if (await _auth.authenticate(
    localizedReason: 'Unlock',
    persistAcrossBackgrounding: true,
    biometricOnly: true,
  )) {}
}

// ---------------------------------------------------------------------------
// local_auth_platform_exception_catch
// ---------------------------------------------------------------------------

/// BAD: PlatformException is never thrown by local_auth 3.0; the catch is dead.
Future<void> badPlatformExceptionCatch() async {
  try {
    if (await _auth.authenticate(localizedReason: 'Verify')) {}
    // expect_lint: local_auth_platform_exception_catch
  } on PlatformException catch (e) {
    _handlePlatform(e);
  }
}

/// GOOD: catch LocalAuthException, which is what 3.0 actually throws.
Future<void> goodPlatformExceptionCatch() async {
  try {
    if (await _auth.authenticate(localizedReason: 'Verify')) {}
  } on LocalAuthException catch (e) {
    _showError(e);
  }
}

// ---------------------------------------------------------------------------
// Stubs to keep the fixture self-contained.
// ---------------------------------------------------------------------------

void _showError(Object e) {}
void _handlePlatform(PlatformException e) {}

// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `local_auth_missing_lockout_handling` (INFO).
library;

import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();

Future<void> bad() async {
  try {
    final ok = await auth.authenticate(localizedReason: 'Unlock');
  }
  // expect_lint: local_auth_missing_lockout_handling
  on LocalAuthException catch (e) {
    showError('Auth failed');
  }
}

Future<void> good() async {
  try {
    final ok = await auth.authenticate(localizedReason: 'Unlock');
  } on LocalAuthException catch (e) {
    if (e.code == LocalAuthExceptionCode.biometricLockout) showLockout();
  }
}

void showError(String s) {}
void showLockout() {}

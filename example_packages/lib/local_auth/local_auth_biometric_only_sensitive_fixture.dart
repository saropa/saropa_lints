// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `local_auth_biometric_only_sensitive` (pedantic, INFO).
/// Quick fix adds biometricOnly: true.
library;

import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();

Future<void> confirmPayment() async {
  // expect_lint: local_auth_biometric_only_sensitive
  final ok = await auth.authenticate(localizedReason: 'Confirm payment');
}

Future<void> confirmPaymentGood() async {
  final ok = await auth.authenticate(
    localizedReason: 'Confirm payment',
    biometricOnly: true,
  );
}

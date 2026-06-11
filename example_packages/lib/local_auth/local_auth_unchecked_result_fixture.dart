// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `local_auth_unchecked_result`.
library;

import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();

Future<void> bad() async {
  // expect_lint: local_auth_unchecked_result
  await auth.authenticate(localizedReason: 'Unlock');
  openVault();
}

Future<void> good() async {
  if (await auth.authenticate(localizedReason: 'Unlock')) openVault();
}

void openVault() {}

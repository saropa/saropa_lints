// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `local_auth_unhandled_exception`.
library;

import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();

Future<void> bad() async {
  if (await auth.isDeviceSupported()) {
    // expect_lint: local_auth_unhandled_exception
    final ok = await auth.authenticate(localizedReason: 'Unlock');
  }
}

Future<void> good() async {
  try {
    final ok = await auth.authenticate(localizedReason: 'Unlock');
  } on LocalAuthException catch (e) {
    handle(e);
  }
}

void handle(Object e) {}

// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `local_auth_missing_capability_check` (INFO).
library;

import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();

Future<void> bad() async {
  // expect_lint: local_auth_missing_capability_check
  final ok = await auth.authenticate(localizedReason: 'Unlock');
}

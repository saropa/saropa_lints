// ignore_for_file: unused_local_variable, unused_element

import 'package:saropa_lints_example/flutter_mocks.dart';

/// Fixture for `prefer_biometric_protection` lint rule.
///
/// BAD: FlutterSecureStorage() without authenticationRequired in options.
/// GOOD: FlutterSecureStorage with aOptions/iOptions authenticationRequired: true.

void badNoOptions() {
  // LINT: prefer_biometric_protection
  final storage = FlutterSecureStorage();
}

void badOptionsWithoutAuth() {
  // LINT: prefer_biometric_protection
  final storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
}

void goodWithBiometric() {
  // OK: authenticationRequired: true
  final storage = FlutterSecureStorage(
    aOptions: AndroidOptions(authenticationRequired: true),
    iOptions: IOSOptions(authenticationRequired: true),
  );
}

void goodIOSOnly() {
  // OK: iOptions has authenticationRequired
  final storage = FlutterSecureStorage(
    iOptions: IOSOptions(authenticationRequired: true),
  );
}

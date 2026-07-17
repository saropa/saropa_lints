// ignore_for_file: unused_element, undefined_identifier, undefined_method
// ignore_for_file: undefined_class
// Compliant example for require_apple_sign_in, kept in its own file.
// The rule is whole-file: any Apple sign-in indicator suppresses the report, so
// this must not share a file with the BAD fixture.
import 'package:saropa_lints_example/flutter_mocks.dart';

// GOOD: Should NOT trigger require_apple_sign_in — offers both options.
void goodAppleSignIn() async {
  await GoogleSignIn().signIn();
  // elsewhere in the app
  await SignInWithApple.getAppleIDCredential();
}

// ignore_for_file: unused_element
// Fixture for require_firebase_app_check_production.
// Rule requires App Check (or equivalent) in production for Firebase APIs.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: no App Check activation anywhere in the file — should trigger.
// expect_lint: require_firebase_app_check_production
void _bad_initFirebaseNoAppCheck() async {
  await Firebase.initializeApp();
}

// GOOD: App Check activated in the same function body — should NOT trigger.
void _good_initFirebaseSameFunction() async {
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate();
}

// GOOD: App Check is activated in a separate top-level function in the same
// file (e.g. a deferred startup task so a slow/flaky provider check can't
// block first frame) — should NOT trigger.
void _good_initFirebaseDeferred() async {
  await Firebase.initializeApp();
}

void _good_activateAppCheckLater() async {
  await FirebaseAppCheck.instance.activate();
}

// ignore_for_file: unused_import

/// Fixture for `require_notification_icon_kept`.
///
/// Assumes shrinker rules omit drawable keeps (typical false positive driver).
import 'package:firebase_messaging/firebase_messaging.dart';

void registerPush() {
  // LINT: Import FCM without ProGuard drawable keeps in android/app/proguard-rules.pro
  FirebaseMessaging.instance;
}

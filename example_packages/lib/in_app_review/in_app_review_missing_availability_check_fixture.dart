// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `in_app_review_missing_availability_check`.
///
/// BAD: requestReview() with no isAvailable() guard in the member.
/// GOOD: gated on isAvailable().
library;

import 'package:in_app_review/in_app_review.dart';

Future<void> bad() async {
  // expect_lint: in_app_review_missing_availability_check
  await InAppReview.instance.requestReview();
}

Future<void> good() async {
  if (await InAppReview.instance.isAvailable()) {
    await InAppReview.instance.requestReview();
  }
}

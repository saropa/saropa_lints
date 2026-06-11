// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `in_app_review_ios_store_listing_missing_app_id`.
///
/// BAD: openStoreListing() with no appStoreId (or null) on an Apple-targeting
/// project. GOOD: a concrete App Store id. Fires only when the project has an
/// ios/ or macos/ directory.
library;

import 'package:in_app_review/in_app_review.dart';

Future<void> badOmitted() async {
  // expect_lint: in_app_review_ios_store_listing_missing_app_id
  await InAppReview.instance.openStoreListing();
}

Future<void> badNull() async {
  // expect_lint: in_app_review_ios_store_listing_missing_app_id
  await InAppReview.instance.openStoreListing(appStoreId: null);
}

Future<void> good() async {
  await InAppReview.instance.openStoreListing(appStoreId: '1234567890');
}

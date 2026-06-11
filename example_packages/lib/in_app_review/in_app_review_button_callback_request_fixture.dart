// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `in_app_review_button_callback_request`.
///
/// BAD: requestReview() wired to an onPressed callback. GOOD: openStoreListing
/// in the button; requestReview only at a post-engagement point.
library;

import 'package:in_app_review/in_app_review.dart';

class FakeButton {
  FakeButton({required this.onPressed});
  final void Function() onPressed;
}

FakeButton bad() {
  return FakeButton(
    // expect_lint: in_app_review_button_callback_request
    onPressed: () => InAppReview.instance.requestReview(),
  );
}

FakeButton good() {
  return FakeButton(
    onPressed: () => InAppReview.instance.openStoreListing(appStoreId: '123'),
  );
}

Future<void> goodPostEngagement() async {
  // Not in a button callback — allowed.
  await InAppReview.instance.requestReview();
}

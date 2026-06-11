// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `in_app_review_missing_store_listing_fallback` (INFO).
///
/// BAD: a class with a rate button calling requestReview() and no
/// openStoreListing() fallback anywhere. GOOD: the class also offers
/// openStoreListing().
library;

import 'package:in_app_review/in_app_review.dart';

class FakeButton {
  FakeButton({required this.onPressed});
  final void Function() onPressed;
}

class BadRateCard {
  FakeButton build() {
    return FakeButton(
      // expect_lint: in_app_review_missing_store_listing_fallback
      onPressed: () => InAppReview.instance.requestReview(),
    );
  }
}

class GoodRateCard {
  FakeButton buildReview() =>
      FakeButton(onPressed: () => InAppReview.instance.requestReview());

  FakeButton buildFallback() => FakeButton(
    onPressed: () => InAppReview.instance.openStoreListing(appStoreId: '123'),
  );
}

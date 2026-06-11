// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `in_app_review_request_in_init_state`.
///
/// BAD: requestReview() in a State.initState() override. GOOD: triggered from a
/// post-engagement method instead.
library;

import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';

class BadWidget extends StatefulWidget {
  const BadWidget({super.key});
  @override
  State<BadWidget> createState() => _BadWidgetState();
}

class _BadWidgetState extends State<BadWidget> {
  @override
  void initState() {
    super.initState();
    // expect_lint: in_app_review_request_in_init_state
    InAppReview.instance.requestReview();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class GoodWidget extends StatefulWidget {
  const GoodWidget({super.key});
  @override
  State<GoodWidget> createState() => _GoodWidgetState();
}

class _GoodWidgetState extends State<GoodWidget> {
  Future<void> onMilestoneReached() async {
    await InAppReview.instance.requestReview();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

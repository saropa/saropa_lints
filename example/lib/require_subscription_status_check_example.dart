import 'package:flutter/material.dart';

// BAD: Premium content shown without verifying subscription status
class BadPremiumScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Welcome to Premium!'),
        PremiumContent(), // No status check
      ],
    );
  }
}

// GOOD: Premium content shown only if subscription is verified
class GoodPremiumScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SubscriptionService.checkStatus(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return PremiumContent();
        }
        return UpgradePrompt();
      },
    );
  }
}

class PremiumContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('Premium Content!');
}

class UpgradePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text('Please upgrade to access premium features.');
}

// FALSE POSITIVE TEST: These should NOT trigger the rule
// even though they contain premium indicators as substrings
class LayoutHelpers {
  // OK: "isPro" is a substring but "isProportional" is not a premium indicator
  bool get isProportional => true;

  // OK: "pro" is a substring but "processData" is not a premium indicator
  void processData() {}

  // OK: "premium" is a substring but "premiumQuality" describes quality, not access
  String get premiumQualityDescription => 'High quality';
}

class SubscriptionService {
  static Future<bool> checkStatus() async {
    // Simulate a real check
    await Future.delayed(Duration(milliseconds: 100));
    return false;
  }
}

import 'package:saropa_lints/src/rules/packages/go_router_6_rules.dart';
import 'package:test/test.dart';

/// Instantiation pins for the go_router_6 migration pack rules.
///
/// Behavioral verification is via the scan CLI against
/// example_packages/lib/go_router/* (see CONTRIBUTING.md); CI does not run
/// fixtures.
void main() {
  group('go_router 6 Rules - Rule Instantiation', () {
    test('AvoidGoRouterLegacyRedirectRule', () {
      final rule = AvoidGoRouterLegacyRedirectRule();
      expect(rule.code.lowerCaseName, 'avoid_go_router_legacy_redirect');
      expect(
        rule.code.problemMessage,
        contains('[avoid_go_router_legacy_redirect]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}

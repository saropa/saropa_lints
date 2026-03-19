import 'package:saropa_lints/saropa_lints.dart' show RuleType;
import 'package:saropa_lints/src/rules/security/security_auth_storage_rules.dart';
import 'package:saropa_lints/src/rules/security/security_network_input_rules.dart';
import 'package:test/test.dart';

void main() {
  group('Security Rules - metadata (CWE, ruleType)', () {
    test('WebView JS enabled is a securityHotspot with CWE-79', () {
      final rule = AvoidWebViewJavaScriptEnabledRule();
      expect(rule.ruleType, RuleType.securityHotspot);
      expect(rule.cweIds, contains(79));
    });

    test('WebView mixed content is a securityHotspot with CWE-319', () {
      final rule = AvoidWebViewInsecureContentRule();
      expect(rule.ruleType, RuleType.securityHotspot);
      expect(rule.cweIds, contains(319));
    });

    test('WebView CORS bypass is a securityHotspot with CWE-346', () {
      final rule = AvoidWebViewCorsIssuesRule();
      expect(rule.ruleType, RuleType.securityHotspot);
      expect(rule.cweIds, contains(346));
    });

    test('Redirect injection is a securityHotspot with CWE-601', () {
      final rule = AvoidRedirectInjectionRule();
      expect(rule.ruleType, RuleType.securityHotspot);
      expect(rule.cweIds, contains(601));
    });

    test('Prefer WebView sandbox is a securityHotspot with CWE-284', () {
      final rule = PreferWebviewSandboxRule();
      expect(rule.ruleType, RuleType.securityHotspot);
      expect(rule.cweIds, contains(284));
    });

    test(
      'WebView missing error handling is a securityHotspot with CWE-703',
      () {
        final rule = RequireWebViewErrorHandlingRule();
        expect(rule.ruleType, RuleType.securityHotspot);
        expect(rule.cweIds, contains(703));
      },
    );

    test('Dynamic SQL injection is vulnerability with CWE-89', () {
      final rule = AvoidDynamicSqlRule();
      expect(rule.ruleType, RuleType.vulnerability);
      expect(rule.cweIds, contains(89));
    });
  });
}

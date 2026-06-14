// Oracle-backed regression tests for security_network_input_rules false
// positives (2026.06 audit). Each test reproduces a specific over-report, then
// pins the corrected behavior. Flutter/webview types are stubbed locally so the
// resolved harness runs without a Flutter dependency.
library;

import 'package:saropa_lints/src/rules/security/security_network_input_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  // The OAuth carve-out only matters for identifiers like `oauthToken` where a
  // sensitive substring (`token`) appears inside a non-sensitive OAuth name.
  group('avoid_logging_sensitive_data', () {
    test('BAD: logging a raw password fires', () async {
      final codes = await reportedRuleCodes(
        AvoidLoggingSensitiveDataRule(),
        '''
void f(String password) {
  print('user password: \$password');
}
''',
      );
      expect(codes, contains('avoid_logging_sensitive_data'));
    });

    test('GOOD: logging an OAuth flow event (oauthToken) stays silent',
        () async {
      // `oauthToken` embeds `token` but is an OAuth protocol identifier, not a
      // secret credential value. The safe-pattern carve-out must suppress it.
      final codes = await reportedRuleCodes(
        AvoidLoggingSensitiveDataRule(),
        '''
void f(String oauthToken) {
  print('oauthToken refreshed: \$oauthToken');
}
''',
      );
      expect(codes, isNot(contains('avoid_logging_sensitive_data')));
    });

    test('GOOD: logging a generic authentication status stays silent',
        () async {
      final codes = await reportedRuleCodes(
        AvoidLoggingSensitiveDataRule(),
        '''
void f(bool authenticated) {
  print('authentication complete: \$authenticated');
}
''',
      );
      expect(codes, isNot(contains('avoid_logging_sensitive_data')));
    });
  });

  // The webview rule must inspect the boolean VALUE of the relevant named arg,
  // not scan the whole argument source for the literal `true`.
  group('avoid_webview_javascript_enabled', () {
    const String stubs = '''
class InAppWebViewSettings {
  const InAppWebViewSettings({this.javaScriptEnabled, this.isInspectable});
  final bool? javaScriptEnabled;
  final bool? isInspectable;
}
class InAppWebView {
  const InAppWebView({this.initialSettings});
  final InAppWebViewSettings? initialSettings;
}
''';

    test('BAD: javaScriptEnabled true in settings fires', () async {
      final codes = await reportedRuleCodes(
        AvoidWebViewJavaScriptEnabledRule(),
        '''
$stubs
Object build() => const InAppWebView(
  initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
);
''',
      );
      expect(codes, contains('avoid_webview_javascript_enabled'));
    });

    test('GOOD: javaScriptEnabled false with unrelated isInspectable:true '
        'stays silent', () async {
      // The `true` here belongs to isInspectable, not the JS toggle. A
      // substring scan of the argument source wrongly flags this.
      final codes = await reportedRuleCodes(
        AvoidWebViewJavaScriptEnabledRule(),
        '''
$stubs
Object build() => const InAppWebView(
  initialSettings: InAppWebViewSettings(
    javaScriptEnabled: false,
    isInspectable: true,
  ),
);
''',
      );
      expect(codes, isNot(contains('avoid_webview_javascript_enabled')));
    });
  });
}

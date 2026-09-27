/// Resolved-AST false-positive regression tests for
/// require_permission_plist_ios. iOS notification authorization needs no
/// Info.plist usage-description key, so `Permission.notification.request()`
/// must stay silent while protected resources (camera, location, ...) still
/// fire.
///
/// The rule is {FileType.widget}, so each fixture carries an
/// `extends StatelessWidget` substring or the rule never runs.
library;

import 'package:saropa_lints/src/rules/widget/widget_patterns_require_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  const stubs = '''
class Widget { const Widget(); }
abstract class StatelessWidget extends Widget { const StatelessWidget(); }
class Home extends StatelessWidget { const Home(); }
class Permission {
  static const Permission camera = Permission._();
  static const Permission notification = Permission._();
  const Permission._();
  Future<void> request() async {}
}
extension RequestAll on List<Permission> {
  Future<void> request() async {}
}
''';

  group('require_permission_plist_ios', () {
    final rule = RequirePermissionPlistIosRule();
    const ruleName = 'require_permission_plist_ios';

    test('FP: Permission.notification.request() stays silent', () async {
      const code =
          '''
$stubs
Future<void> ask() async {
  await Permission.notification.request();
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    test('BAD: Permission.camera.request() fires', () async {
      const code =
          '''
$stubs
Future<void> ask() async {
  await Permission.camera.request();
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    test('BAD: list mixing camera and notification fires', () async {
      const code =
          '''
$stubs
Future<void> ask() async {
  await [Permission.camera, Permission.notification].request();
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });
}

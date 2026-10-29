/// Resolved-AST regression tests for require_ios_face_id_usage_description.
///
/// Builds a real temp project (pubspec + ios/Runner/Info.plist) and runs the
/// rule on a nested `lib/` fixture using a local `LocalAuthentication` stub
/// (the fixture resolves against the SDK only, so no package imports).
library;

import 'dart:io';

import 'package:saropa_lints/src/info_plist_utils.dart';
import 'package:saropa_lints/src/rules/platforms/ios_capabilities_permissions_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/safe_delete.dart';

void main() {
  const ruleName = 'require_ios_face_id_usage_description';
  const fixture = '''
class LocalAuthentication {
  Future<bool> authenticate({required String localizedReason}) async => true;
  Future<bool> isDeviceSupported() async => true;
}

final LocalAuthentication auth = LocalAuthentication();
Future<bool> go() => auth.authenticate(localizedReason: 'Unlock');
''';

  group(ruleName, () {
    final rule = RequireIosFaceIdUsageDescriptionRule();
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('face_id_plist_');
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: app\n');
      Directory('${project.path}/ios/Runner').createSync(recursive: true);
    });

    tearDown(() {
      safeDeleteDir(project);
      InfoPlistChecker.clearCache();
    });

    void writePlist(String body) => File(
      '${project.path}/ios/Runner/Info.plist',
    ).writeAsStringSync('<plist version="1.0"><dict>$body</dict></plist>');

    Future<int> hits() async => (await runRuleResolved(
      rule,
      fixture,
      projectRoot: project,
    )).where((d) => d.ruleName == ruleName).length;

    test('GOOD: plist declares NSFaceIDUsageDescription -> silent', () async {
      writePlist(
        '<key>NSFaceIDUsageDescription</key>'
        '<string>Uses Face ID to unlock protected items.</string>',
      );
      expect(await hits(), 0);
    });

    test('BAD: plist without the key -> reports', () async {
      writePlist('<key>CFBundleIdentifier</key><string>x</string>');
      expect(await hits(), greaterThan(0));
    });
  });
}

/// Resolved-AST regression tests for require_permission_plist_ios.
///
/// The rule reads the project's real `ios/Runner/Info.plist` and reports a
/// `Permission.<x>.request()` only when a key that permission needs is
/// missing. Each test builds a throwaway project (pubspec + optional plist)
/// and runs the rule on a fixture under its `lib/`.
///
/// The rule is {FileType.widget}, so each fixture carries an
/// `extends StatelessWidget` substring or the rule never runs.
library;

import 'dart:io';

import 'package:saropa_lints/src/info_plist_utils.dart';
import 'package:saropa_lints/src/rules/widget/widget_patterns_require_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/safe_delete.dart';

void main() {
  const stubs = '''
class Widget { const Widget(); }
abstract class StatelessWidget extends Widget { const StatelessWidget(); }
class Home extends StatelessWidget { const Home(); }
class Permission {
  static const Permission camera = Permission._();
  static const Permission microphone = Permission._();
  static const Permission notification = Permission._();
  static const Permission criticalAlerts = Permission._();
  static const Permission sms = Permission._();
  static const Permission systemAlertWindow = Permission._();
  static const Permission calendar = Permission._();
  static const Permission locationAlways = Permission._();
  const Permission._();
  Future<void> request() async {}
}
extension RequestAll on List<Permission> {
  Future<void> request() async {}
}
''';

  String fixture(String call) =>
      '''
$stubs
Future<void> ask() async {
  await $call;
}
''';

  String plist(List<String> keys) =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.example</string>
${keys.map((k) => '  <key>$k</key>\n  <string>Reason</string>').join('\n')}
  <key>UIBackgroundModes</key>
  <array>
    <string>audio</string>
  </array>
</dict>
</plist>
''';

  group('require_permission_plist_ios', () {
    final rule = RequirePermissionPlistIosRule();
    const ruleName = 'require_permission_plist_ios';
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('perm_plist_ios_');
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: app\n');
      Directory('${project.path}/ios/Runner').createSync(recursive: true);
    });

    tearDown(() {
      safeDeleteDir(project);
      InfoPlistChecker.clearCache();
    });

    void writePlist(List<String> keys) => File(
      '${project.path}/ios/Runner/Info.plist',
    ).writeAsStringSync(plist(keys));

    Future<List<HarnessDiagnostic>> run(String call) =>
        runRuleResolved(rule, fixture(call), projectRoot: project);

    // The reported case: notification permission with a plist that has only
    // background audio configured and no usage-description keys.
    test(
      'FP: Permission.notification.request() stays silent without keys',
      () async {
        writePlist(const []);
        final diags = await run('Permission.notification.request()');
        expect(diags.map((d) => d.ruleName), isNot(contains(ruleName)));
      },
    );

    for (final name in ['criticalAlerts', 'sms', 'systemAlertWindow']) {
      test('FP: Permission.$name needs no plist key', () async {
        writePlist(const []);
        final diags = await run('Permission.$name.request()');
        expect(diags.map((d) => d.ruleName), isNot(contains(ruleName)));
      });
    }

    test('FP: camera stays silent when its key is declared', () async {
      writePlist(const ['NSCameraUsageDescription']);
      final diags = await run('Permission.camera.request()');
      expect(diags.map((d) => d.ruleName), isNot(contains(ruleName)));
    });

    test('FP: no Info.plist means nothing can be confirmed missing', () async {
      final diags = await run('Permission.camera.request()');
      expect(diags.map((d) => d.ruleName), isNot(contains(ruleName)));
    });

    test('FP: calendar accepts the iOS 17 full-access key', () async {
      writePlist(const ['NSCalendarsFullAccessUsageDescription']);
      final diags = await run('Permission.calendar.request()');
      expect(diags.map((d) => d.ruleName), isNot(contains(ruleName)));
    });

    Future<int> hits(String call) async =>
        (await run(call)).where((d) => d.ruleName == ruleName).length;

    test('BAD: camera without its key fires', () async {
      writePlist(const []);
      expect(await hits('Permission.camera.request()'), 1);
    });

    test('BAD: list with camera and notification fires', () async {
      writePlist(const []);
      expect(
        await hits('[Permission.camera, Permission.notification].request()'),
        1,
      );
    });

    test('BAD: list fires when one permission lacks its key', () async {
      writePlist(const ['NSCameraUsageDescription']);
      expect(
        await hits('[Permission.camera, Permission.microphone].request()'),
        1,
      );
    });

    test('GOOD: list with every key declared stays silent', () async {
      writePlist(const [
        'NSCameraUsageDescription',
        'NSMicrophoneUsageDescription',
      ]);
      expect(
        await hits('[Permission.camera, Permission.microphone].request()'),
        0,
      );
    });

    test('BAD: locationAlways needs the always key too', () async {
      writePlist(const ['NSLocationWhenInUseUsageDescription']);
      expect(await hits('Permission.locationAlways.request()'), 1);
    });
  });

  group('IosPermissionHandlerMapping.missingKeys', () {
    bool none(String _) => false;

    test('permissions needing no key contribute nothing', () {
      expect(
        IosPermissionHandlerMapping.missingKeys(const [
          'notification',
          'criticalAlerts',
          'backgroundRefresh',
          'storage',
          'phone',
          'sms',
          'ignoreBatteryOptimizations',
          'scheduleExactAlarm',
          'bluetoothConnect',
        ], none),
        isEmpty,
      );
    });

    test('unknown permission names contribute nothing', () {
      expect(
        IosPermissionHandlerMapping.missingKeys(const ['futureThing'], none),
        isEmpty,
      );
    });

    test('any-of groups render with "or" and dedupe', () {
      expect(
        IosPermissionHandlerMapping.missingKeys(const [
          'location',
          'locationWhenInUse',
          'calendar',
        ], none),
        [
          'NSLocationWhenInUseUsageDescription',
          'NSCalendarsUsageDescription or '
              'NSCalendarsFullAccessUsageDescription',
        ],
      );
    });

    test('a satisfied group is not reported', () {
      expect(
        IosPermissionHandlerMapping.missingKeys(const [
          'bluetooth',
        ], (k) => k == 'NSBluetoothPeripheralUsageDescription'),
        isEmpty,
      );
    });
  });
}

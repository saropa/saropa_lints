/// Behavior tests for `prefer_platform_widget_adaptive`.
///
/// The rule proves widgets come from Flutter by element, so a temp project
/// maps `package:flutter` to a minimal stub.
library;

import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/src/rules/config/platform_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/safe_delete.dart';

const String _flutterStub = '''
enum TargetPlatform { iOS, android }
const TargetPlatform defaultTargetPlatform = TargetPlatform.android;
class Widget { const Widget(); }
class ThemeData {
  ThemeData({this.platform = TargetPlatform.android});
  final TargetPlatform platform;
}
class MaterialApp extends Widget { MaterialApp({Object? theme, Widget? home}); }
class Switch extends Widget {
  const Switch({bool value = false});
  const Switch.adaptive({bool value = false});
}
class CircularProgressIndicator extends Widget {
  const CircularProgressIndicator();
}
class CupertinoSwitch extends Widget { const CupertinoSwitch(); }
''';

const String _import = "import 'package:flutter/material.dart';\n";

void main() {
  late Directory root;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('adaptive_rule_');
    File('${root.path}/flutter/lib/material.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(_flutterStub);
    File('${root.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'flutter',
              'rootUri': '../flutter/',
              'packageUri': 'lib/',
              'languageVersion': '3.5',
            },
          ],
        }),
      );
  });

  tearDownAll(() => safeDeleteDir(root));

  Future<int> count(String code) async {
    final diags = await runRuleResolved(
      PreferPlatformWidgetAdaptiveRule(),
      code,
      projectRoot: root,
    );
    return diags.length;
  }

  test('Material controls with an unused .adaptive are reported', () async {
    expect(
      await count('''
${_import}Widget a() => const Switch(value: true);
Widget b() => const CircularProgressIndicator();
Widget c(bool busy) => busy ? const Switch() : const Widget();
'''),
      3,
    );
  });

  test('MaterialApp and .adaptive are not reported', () async {
    expect(
      await count('''
${_import}Widget a() => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.iOS),
);
Widget b() => const Switch.adaptive(value: true);
'''),
      0,
    );
  });

  test('platform-branched controls are not reported', () async {
    expect(
      await count('''
import 'dart:io';
${_import}Widget a() =>
    Platform.isIOS ? const CupertinoSwitch() : const Switch();
Widget b(ThemeData theme) {
  if (theme.platform == TargetPlatform.iOS) return const CupertinoSwitch();
  return const Switch();
}
Widget c() => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => const CupertinoSwitch(),
  _ => const Switch(),
};
'''),
      0,
    );
  });

  test('a same-named local class is not reported', () async {
    expect(
      await count('''
class Switch { const Switch(); }
Object a() => const Switch();
'''),
      0,
    );
  });
}

import 'dart:io';

import 'package:saropa_lints/src/init/cli_args.dart';
import 'package:saropa_lints/src/init/composite_plugin_scaffold.dart';
import 'package:test/test.dart';

void main() {
  test('emitCompositePluginScaffold writes plugin package files', () {
    final dir = Directory.systemTemp.createTempSync('saropa_composite_');
    try {
      emitCompositePluginScaffold(dir);
      expect(File('${dir.path}/pubspec.yaml').existsSync(), isTrue);
      expect(File('${dir.path}/lib/main.dart').existsSync(), isTrue);
      expect(File('${dir.path}/README.md').existsSync(), isTrue);
      final main = File('${dir.path}/lib/main.dart').readAsStringSync();
      expect(main, contains('registerSaropaLintRules'));
      expect(main, contains('class SaropaCompositePlugin'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test(
    'parseArguments accepts --emit-composite-plugin-scaffold default dir',
    () {
      final args = parseArguments(['--emit-composite-plugin-scaffold']);
      expect(args.emitCompositePluginScaffold, 'composite_saropa_plugin');
    },
  );

  test('parseArguments accepts explicit scaffold output path', () {
    final args = parseArguments([
      '--emit-composite-plugin-scaffold',
      'packages/acme_saropa',
    ]);
    expect(args.emitCompositePluginScaffold, 'packages/acme_saropa');
  });
}

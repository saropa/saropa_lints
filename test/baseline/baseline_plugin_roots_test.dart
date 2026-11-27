// The in-server plugin loads config once, for one project root, but must
// check every analyzed file against that file's own project baseline.
// Separate file because marking the plugin as started is process-global.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot, markNativePluginStarted;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  test('a second root uses its own baseline, not the loaded one', () {
    final dir = Directory.systemTemp.createTempSync('saropa_plugin_roots_');
    addTearDown(() {
      BaselineManager.reset();
      safeDeleteDir(dir);
    });

    /// A package whose custom options baseline `lib/[name].dart`.
    String package(String name) {
      final root = p.join(dir.path, name);
      Directory(root).createSync();
      File(p.join(root, 'pubspec.yaml')).writeAsStringSync('name: $name\n');
      File(p.join(root, 'analysis_options_custom.yaml')).writeAsStringSync(
        'baseline:  # trailing comment\n  paths: ["lib/$name.dart"]\n',
      );
      return root;
    }

    final a = package('a');
    final b = package('b');
    markNativePluginStarted();
    loadNativePluginConfigFromProjectRoot(a);

    bool baselined(String root, String file) =>
        BaselineManager.isBaselined(p.join(root, 'lib', file), 'r', 1);

    expect(baselined(a, 'a.dart'), isTrue);
    expect(baselined(b, 'b.dart'), isTrue);
    expect(baselined(b, 'a.dart'), isFalse);
  });
}

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
import '../support/temp_git.dart';

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

  // The plugin reloads config for whichever root it saw; every project must
  // keep its own date and path settings, and edits must apply each time.
  test('repeated reloads keep date and path baselines per project', () {
    final dir = Directory.systemTemp.createTempSync('saropa_plugin_reload_');
    addTearDown(() {
      BaselineManager.reset();
      safeDeleteDir(dir);
    });
    final a = p.join(dir.path, 'a');
    final b = p.join(dir.path, 'b');
    for (final root in [a, b]) {
      Directory(p.join(root, 'lib', 'legacy')).createSync(recursive: true);
      File(p.join(root, 'pubspec.yaml')).writeAsStringSync('name: t\n');
      File(p.join(root, 'lib', 'x.dart')).writeAsStringSync('x\n');
    }
    tempGit(dir.path, ['init', '-q']);
    tempCommit(dir.path, 'old');

    /// Writes [root]'s section with cutoff [day] and one legacy folder.
    void configure(String root, String day) =>
        File(p.join(root, 'analysis_options_custom.yaml')).writeAsStringSync(
          'baseline:\n  date: "$day"\n  paths: ["lib/legacy/"]\n',
        );

    bool baselined(String root, String relative) =>
        BaselineManager.isBaselined(p.join(root, 'lib', relative), 'r', 1);

    markNativePluginStarted();
    for (var i = 0; i < 3; i++) {
      configure(a, '2022-01-01');
      configure(b, '2010-01-01');
      loadNativePluginConfigFromProjectRoot(i.isEven ? a : b);
      expect(baselined(a, 'x.dart'), isTrue, reason: 'pass $i');
      expect(baselined(b, 'x.dart'), isFalse, reason: 'pass $i');
      expect(baselined(b, 'legacy/y.dart'), isTrue, reason: 'pass $i');

      // Swapped cutoffs must take effect after the next reload.
      configure(a, '2010-01-01');
      configure(b, '2022-01-01');
      loadNativePluginConfigFromProjectRoot(i.isEven ? b : a);
      expect(baselined(a, 'x.dart'), isFalse, reason: 'pass $i');
      expect(baselined(b, 'x.dart'), isTrue, reason: 'pass $i');
    }
  });
}

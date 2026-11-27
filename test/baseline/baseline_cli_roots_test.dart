// The scan CLI, scan daemon and LSP server never start the plugin, yet they
// load config once per process (SaropaContext's lazy reload) from the first
// analyzed file's package. A scan of a folder that holds several packages
// must still check each file against its own package's baseline.
// Separate file because config-loader state is process-global: this file
// must never call markNativePluginStarted, which other tests do.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot;
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  test('without plugin start, a second package uses its own baseline', () {
    final dir = Directory.systemTemp.createTempSync('saropa_cli_roots_');
    addTearDown(() {
      BaselineManager.reset();
      safeDeleteDir(dir);
    });

    /// A package whose custom options baseline only `lib/[name].dart`.
    String package(String name) {
      final root = p.join(dir.path, name);
      Directory(root).createSync();
      File(p.join(root, 'pubspec.yaml')).writeAsStringSync('name: $name\n');
      File(
        p.join(root, 'analysis_options_custom.yaml'),
      ).writeAsStringSync('baseline:\n  paths: ["lib/$name.dart"]\n');
      return root;
    }

    final one = package('one');
    final two = package('two');
    // The lazy reload runs for the first analyzed file's package only.
    loadNativePluginConfigFromProjectRoot(one);

    bool baselined(String root, String file) =>
        BaselineManager.isBaselined(p.join(root, 'lib', file), 'r', 1);

    expect(baselined(one, 'one.dart'), isTrue);
    // Before the fix the CLI paths kept one global baseline, so the second
    // package's own `paths:` entry never applied.
    expect(baselined(two, 'two.dart'), isTrue);
    // The first package's pattern must not leak into its sibling.
    expect(baselined(two, 'one.dart'), isFalse);
  });

  // A package with no baseline section, beside one that has one, must keep
  // every finding: the loaded package's baseline belongs to that package.
  test('a sibling package without a baseline hides nothing', () {
    final dir = Directory.systemTemp.createTempSync('saropa_cli_roots_none_');
    addTearDown(() {
      BaselineManager.reset();
      safeDeleteDir(dir);
    });
    final one = p.join(dir.path, 'one');
    final two = p.join(dir.path, 'two');
    for (final root in [one, two]) {
      Directory(root).createSync();
      File(p.join(root, 'pubspec.yaml')).writeAsStringSync('name: t\n');
    }
    File(
      p.join(one, 'analysis_options_custom.yaml'),
    ).writeAsStringSync('baseline:\n  paths: ["lib/"]\n');
    loadNativePluginConfigFromProjectRoot(one);

    expect(
      BaselineManager.isBaselined(p.join(one, 'lib', 'g.dart'), 'r', 1),
      isTrue,
    );
    expect(
      BaselineManager.isBaselined(p.join(two, 'lib', 'g.dart'), 'r', 1),
      isFalse,
    );
  });
}

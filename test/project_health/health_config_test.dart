/// Tests `.saropa_health.yaml` parsing and the allowlist filters.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_health/asset_scanner.dart';
import 'package:saropa_lints/src/cli/project_health/health_config.dart';
import 'package:test/test.dart';

void main() {
  group('loadHealthConfig', () {
    test('absent config is empty (no-op)', () {
      final tmp = Directory.systemTemp.createTempSync('saropa_cfg_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final cfg = loadHealthConfig(tmp.path);
      expect(cfg.excludeGlobs, isEmpty);
      expect(cfg.ignoreDeadFiles, isEmpty);
    });

    test('parses excludes and ignore lists', () {
      final tmp = Directory.systemTemp.createTempSync('saropa_cfg_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File(p.join(tmp.path, '.saropa_health.yaml')).writeAsStringSync('''
exclude:
  - "lib/generated/**"
ignore:
  dead_files: [lib/legacy/orphan.dart]
  dead_symbols: [lib/config_loader.dart]
  islands: [_legacyBoot]
  assets: [assets/keep.png]
''');
      final cfg = loadHealthConfig(tmp.path);
      expect(cfg.excludeGlobs, ['lib/generated/**']);
      expect(cfg.ignoreDeadFiles, contains('lib/legacy/orphan.dart'));
      expect(cfg.ignoreDeadSymbols, contains('lib/config_loader.dart'));
      expect(cfg.ignoreIslands, contains('_legacyBoot'));
      expect(cfg.isAssetIgnored('assets/keep.png'), isTrue);
    });
  });

  group('filters', () {
    const cfg = HealthConfig(
      ignoreDeadFiles: {'lib/a.dart'},
      ignoreDeadSymbols: {'lib/b.dart'},
      ignoreIslands: {'_x'},
    );

    test('dead files allowlisted are removed', () {
      expect(cfg.filterDeadFiles({'lib/a.dart', 'lib/c.dart'}), {'lib/c.dart'});
    });

    test('dead symbols allowlisted files are dropped', () {
      expect(cfg.filterDeadSymbols({'lib/b.dart': 3, 'lib/c.dart': 1}), {
        'lib/c.dart': 1,
      });
    });

    test('island names allowlisted are removed and empty files dropped', () {
      final result = cfg.filterIslands({
        'lib/d.dart': ['_x', '_y'],
        'lib/e.dart': ['_x'],
      });
      expect(result, {
        'lib/d.dart': ['_y'],
      });
    });
  });

  test('AssetFinding paths can be allowlisted', () {
    const cfg = HealthConfig(ignoreAssets: {'assets/keep.png'});
    final findings = [
      const AssetFinding('assets/keep.png', 'unreferenced'),
      const AssetFinding('assets/dead.png', 'unreferenced'),
    ];
    final kept = [
      for (final a in findings)
        if (!cfg.isAssetIgnored(a.path)) a,
    ];
    expect(kept.map((a) => a.path), ['assets/dead.png']);
  });
}

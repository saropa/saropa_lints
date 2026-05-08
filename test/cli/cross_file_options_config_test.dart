import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_options_config.dart';
import 'package:test/test.dart';

void main() {
  group('CrossFileProjectCliOptions', () {
    test('returns empty when analysis_options.yaml is missing', () {
      final dir = Directory.systemTemp.createTempSync('cross_file_cfg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final o = CrossFileProjectCliOptions.load(dir.path);
      expect(o.excludeGlobs, isEmpty);
      expect(o.heuristicDeadImports, isNull);
    });

    test('parses saropa_lints_cross_file section', () {
      final dir = Directory.systemTemp.createTempSync('cross_file_cfg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'analysis_options.yaml')).writeAsStringSync('''
saropa_lints_cross_file:
  excludes:
    - "**/*.g.dart"
    - 'lib/generated/**'
  heuristic_dead_imports: true
  include_private_symbols: true
''');
      final o = CrossFileProjectCliOptions.load(dir.path);
      expect(o.excludeGlobs, ['**/*.g.dart', 'lib/generated/**']);
      expect(o.heuristicDeadImports, isTrue);
      expect(o.includePrivateSymbols, isTrue);
      expect(o.heuristicUnusedSymbols, isNull);
    });
  });
}

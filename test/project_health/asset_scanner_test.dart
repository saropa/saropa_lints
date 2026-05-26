/// Tests for the dead-asset scanner: declared-but-unreferenced and missing.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_health/asset_scanner.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('saropa_assets_');
    Directory(p.join(tmp.path, 'assets')).createSync();
    Directory(p.join(tmp.path, 'lib')).createSync();
    File(p.join(tmp.path, 'assets', 'used.png')).writeAsStringSync('x');
    File(p.join(tmp.path, 'assets', 'orphan.png')).writeAsStringSync('x');
    File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('''
name: demo
flutter:
  assets:
    - assets/used.png
    - assets/orphan.png
    - assets/ghost.png
''');
    // Only used.png is referenced in code.
    File(
      p.join(tmp.path, 'lib', 'main.dart'),
    ).writeAsStringSync("const img = 'assets/used.png';");
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('flags unreferenced declared assets but not referenced ones', () {
    final findings = scanUnusedAssets(tmp.path);
    final byPath = {for (final f in findings) f.path: f.kind};
    expect(byPath['assets/used.png'], isNull); // referenced → not flagged
    expect(byPath['assets/orphan.png'], 'unreferenced');
  });

  test('flags declared assets that do not exist on disk as missing', () {
    final findings = scanUnusedAssets(tmp.path);
    final byPath = {for (final f in findings) f.path: f.kind};
    expect(byPath['assets/ghost.png'], 'missing');
  });

  test('no pubspec yields no findings', () {
    final empty = Directory.systemTemp.createTempSync('saropa_noassets_');
    addTearDown(() => empty.deleteSync(recursive: true));
    expect(scanUnusedAssets(empty.path), isEmpty);
  });
}

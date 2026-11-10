/// Tests that the scan CLI treats an extension-disabled project as "off".
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('scan_disabled_'));
  tearDown(() => dir.deleteSync(recursive: true));

  void writeOptions(String content) => File(
    p.join(dir.path, 'analysis_options.yaml'),
  ).writeAsStringSync(content);

  test('detects the extension OFF marker', () {
    writeOptions(
      '# >>> saropa_lints integration turned OFF by the VS Code extension >>>\n'
      '# plugins:\n#   saropa_lints:\n',
    );
    expect(isScanIntegrationDisabled(dir.path), isTrue);
  });

  test('false for plain config and for a missing file', () {
    expect(isScanIntegrationDisabled(dir.path), isFalse);
    writeOptions('include: package:lints/recommended.yaml\n');
    expect(isScanIntegrationDisabled(dir.path), isFalse);
  });

  test(
    'scan CLI exits 0 and prints a disabled line',
    () async {
      writeOptions(
        '# >>> saropa_lints integration turned OFF by the VS Code extension >>>\n',
      );
      final result = await Process.run('dart', [
        'run',
        'saropa_lints',
        'scan',
        dir.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('disabled'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

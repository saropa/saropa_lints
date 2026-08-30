import 'package:saropa_lints/src/config/max_declarations_config.dart';
import 'package:test/test.dart';

/// Tests for [loadMaxDeclarationsConfig] — parsing `max_declarations_per_file:`
/// from analysis_options_custom.yaml content.
void main() {
  // Reset to default before each test so state doesn't leak
  setUp(() => maxDeclarationsPerFile = 1);

  group('loadMaxDeclarationsConfig', () {
    test('null content resets to default', () {
      maxDeclarationsPerFile = 5;
      loadMaxDeclarationsConfig(null);
      expect(maxDeclarationsPerFile, 1);
    });

    test('empty content resets to default', () {
      maxDeclarationsPerFile = 5;
      loadMaxDeclarationsConfig('');
      expect(maxDeclarationsPerFile, 1);
    });

    test('missing key resets to default', () {
      maxDeclarationsPerFile = 5;
      loadMaxDeclarationsConfig('max_issues: 500\noutput: both');
      expect(maxDeclarationsPerFile, 1);
    });

    test('valid value is parsed', () {
      loadMaxDeclarationsConfig('max_declarations_per_file: 3');
      expect(maxDeclarationsPerFile, 3);
    });

    test('value of 1 is accepted', () {
      loadMaxDeclarationsConfig('max_declarations_per_file: 1');
      expect(maxDeclarationsPerFile, 1);
    });

    test('value of 0 is floored to 1', () {
      loadMaxDeclarationsConfig('max_declarations_per_file: 0');
      expect(maxDeclarationsPerFile, 1);
    });

    test('value among other config lines', () {
      loadMaxDeclarationsConfig(
        'max_issues: 500\n'
        'max_declarations_per_file: 4\n'
        'output: both\n',
      );
      expect(maxDeclarationsPerFile, 4);
    });

    test('commented-out line is ignored', () {
      loadMaxDeclarationsConfig('# max_declarations_per_file: 10');
      expect(maxDeclarationsPerFile, 1);
    });
  });
}

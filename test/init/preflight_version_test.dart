/// Tests for scoped plugin version lookup and unusable-config detection.
library;

import 'package:saropa_lints/src/init/preflight.dart';
import 'package:saropa_lints/src/init/validation.dart';
import 'package:test/test.dart';

void main() {
  group('findSaropaLintsPluginVersion', () {
    test('ignores unrelated version: earlier in the file', () {
      const yaml = '''
analyzer:
  something:
    version: true
plugins:
  saropa_lints:
    version: "17.0.0"
    diagnostics:
      a_rule: true
''';
      expect(findSaropaLintsPluginVersion(yaml), '17.0.0');
    });

    test('returns null when the version belongs to another plugin', () {
      const yaml = '''
plugins:
  other:
    version: "1.0.0"
  saropa_lints:
    diagnostics:
      a_rule: true
''';
      expect(findSaropaLintsPluginVersion(yaml), isNull);
    });

    test('ignores a commented-out block', () {
      const yaml = '# plugins:\n#   saropa_lints:\n#     version: "1"\n';
      expect(findSaropaLintsPluginVersion(yaml), isNull);
    });
  });

  group('isConfigUnusable', () {
    test('commented-out plugin block is unusable', () {
      expect(
        isConfigUnusable('$extensionDisabledMarker >>>\n# plugins:\n'),
        isTrue,
      );
    });

    test('plugins block with zero rules is unusable', () {
      expect(isConfigUnusable('plugins:\n  saropa_lints:\n'), isTrue);
    });

    test('plugins block with a rule is usable', () {
      expect(
        isConfigUnusable(
          'plugins:\n  saropa_lints:\n    diagnostics:\n      a_rule: true\n',
        ),
        isFalse,
      );
    });
  });
}

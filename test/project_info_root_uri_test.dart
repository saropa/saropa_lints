import 'package:saropa_lints/src/init/project_info.dart';
import 'package:test/test.dart';

void main() {
  group('rootUriToPath', () {
    test('parses valid file URI to path', () {
      final path = rootUriToPath('file:///tmp/saropa_lints');
      expect(path, isNotNull);
      expect(path, endsWith('saropa_lints'));
    });

    test('returns null when Uri.tryParse fails (no throw)', () {
      expect(rootUriToPath('file://['), isNull);
    });

    test('relative dart_tool path still resolves when not file scheme', () {
      final path = rootUriToPath('../packages/saropa_lints');
      expect(path, isNotNull);
      expect(path, contains('.dart_tool'));
      expect(path, contains('packages'));
    });
  });
}

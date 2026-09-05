/// Unit tests for [sanitizePath] — the shared CLI path-sanitization guard.
library;

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/path_guard.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizePath', () {
    test('returns normalized clean paths unchanged', () {
      // Relative and absolute paths without traversal pass through.
      expect(sanitizePath('reports'), equals('reports'));
      expect(sanitizePath('build/output'), equals('build${p.separator}output'));
    });

    test('resolves embedded .. and passes safe result', () {
      // `a/../b` normalizes to `b` — no traversal segments remain.
      expect(sanitizePath('a/../b'), equals('b'));
    });

    test('rejects leading .. segments', () {
      // Leading ".." escapes the working directory — must throw.
      expect(() => sanitizePath('../escape'), throwsA(isA<ArgumentError>()));
    });

    test('rejects multiple leading .. segments', () {
      expect(() => sanitizePath('../../etc'), throwsA(isA<ArgumentError>()));
    });

    test('uses custom label in error message', () {
      // Verify the label appears in the thrown error.
      expect(
        () => sanitizePath('../x', label: 'outputDir'),
        throwsA(
          predicate<ArgumentError>(
            (e) => e.message.toString().contains('outputDir'),
          ),
        ),
      );
    });
  });
}

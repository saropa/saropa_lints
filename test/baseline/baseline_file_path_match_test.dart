// Unit tests for [BaselineFile] path matching. A baseline entry must match a
// file only when the paths refer to the same file (exact, or one is a
// path-segment-bounded suffix of the other for relative-vs-absolute cases) —
// never when one filename is merely a textual suffix substring of another.
library;

import 'package:saropa_lints/src/baseline/baseline_file.dart';
import 'package:test/test.dart';

void main() {
  group('BaselineFile.isBaselined path matching', () {
    BaselineFile baselineFor(String path) => BaselineFile(
      violations: {
        path: {
          'avoid_print': [42],
        },
      },
    );

    test('matches an exact path', () {
      final b = baselineFor('lib/a/util.dart');
      expect(b.isBaselined('lib/a/util.dart', 'avoid_print', 42), isTrue);
    });

    test('matches a relative entry against an absolute path (segment suffix)', () {
      final b = baselineFor('lib/a/util.dart');
      expect(
        b.isBaselined('/home/user/proj/lib/a/util.dart', 'avoid_print', 42),
        isTrue,
      );
    });

    test('does NOT match a different file sharing a filename suffix', () {
      // Regression: `endsWith` let baseline entry `util.dart` match the
      // unrelated `my_util.dart`, suppressing a real violation in the wrong
      // file. The suffix must start at a path-segment boundary.
      final b = baselineFor('util.dart');
      expect(b.isBaselined('my_util.dart', 'avoid_print', 42), isFalse);
    });

    test('does NOT match across directories with a shared trailing filename', () {
      final b = baselineFor('lib/a/util.dart');
      expect(
        b.isBaselined('lib/b/extra_util.dart', 'avoid_print', 42),
        isFalse,
      );
    });
  });
}

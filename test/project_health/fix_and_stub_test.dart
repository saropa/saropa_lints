/// Tests for the fix-workflow removal script and stub-test detection.
import 'package:saropa_lints/src/cli/project_health/fix_workflow.dart';
import 'package:saropa_lints/src/cli/project_health/stub_density.dart';
import 'package:test/test.dart';

void main() {
  group('buildRemovalScript', () {
    test('emits reviewable git rm lines, never deletes', () {
      final script = buildRemovalScript(['lib/dead.dart', 'lib/old.dart']);
      expect(script, contains('git rm -- '));
      expect(script, contains("'lib/dead.dart'"));
      expect(script, contains('REVIEW before running'));
    });

    test('empty input yields empty script', () {
      expect(buildRemovalScript(const []), isEmpty);
    });
  });

  group('stubCountIn', () {
    test('test with no assertion is a stub', () {
      expect(stubCountIn("void main() { test('x', () {}); }"), 1);
    });

    test('test with expect is not a stub', () {
      expect(
        stubCountIn("void main() { test('x', () { expect(1, 1); }); }"),
        0,
      );
    });

    test('test with assert is not a stub', () {
      expect(
        stubCountIn("void main() { test('x', () { assert(true); }); }"),
        0,
      );
    });
  });
}

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

  group('emptyBodyStubCountIn', () {
    // The publish/CI gate keys on this narrower definition, so its boundary
    // (empty block = stub; any statement = not) must stay pinned.
    test('empty block body counts as a stub', () {
      expect(emptyBodyStubCountIn("void main() { test('x', () {}); }"), 1);
    });

    test('testWidgets with empty body counts as a stub', () {
      expect(
        emptyBodyStubCountIn("void main() { testWidgets('x', (t) {}); }"),
        1,
      );
    });

    // A non-empty body is NOT an empty-body stub even when it has no
    // expect/assert — this is the "does not throw" pattern the broader
    // stubCountIn flags but the gate must not, so it stays runnable.
    test('non-empty body without an assertion is not an empty-body stub', () {
      const src =
          "void main() { test('x', () { final b = 1; b.toString(); }); }";
      expect(emptyBodyStubCountIn(src), 0);
      expect(stubCountIn(src), 1); // contrast: broader heuristic still flags it
    });

    test('body with only a comment is still an empty block', () {
      expect(
        emptyBodyStubCountIn("void main() { test('x', () { /* todo */ }); }"),
        1,
      );
    });

    // A skipped test never runs, so an empty body cannot silently pass — it is
    // a documented placeholder for an un-runnable case, not a coverage-faking
    // stub. The hard gate must not reject it.
    test('skipped empty-body test is not counted', () {
      expect(
        emptyBodyStubCountIn("void main() { test('x', () {}, skip: 'why'); }"),
        0,
      );
    });

    // Guard against the skip-exclusion over-reaching: an empty-body test with
    // no skip argument is still the real stub the gate exists to catch.
    test('empty-body test without skip is still counted', () {
      expect(
        emptyBodyStubCountIn("void main() { test('x', () {}, timeout: t); }"),
        1,
      );
    });
  });
}

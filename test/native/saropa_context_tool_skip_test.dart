// Tests for SaropaContext.isPathUnderProjectTool — the universal `tool/`
// skip that prevents every saropa rule from firing on repo-local CLI
// utilities (codegen, audits, benchmarks).
//
// Same rationale as the `bin/` skip in saropa_context_bin_skip_test.dart:
// rules that target Flutter UI behavior (avoid_blocking_main_thread,
// avoid_print_in_release, etc.) are unactionable on `tool/` scripts
// because those scripts never run on a Flutter UI isolate. The per-rule
// `isFlutterProject` gate would normally suppress them, but the
// analyzer-plugin worker-isolate pool can serve stale `_projectCache`
// entries that bypass it. Centralising at the SaropaContext layer
// removes the noise uniformly.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/native/saropa_context.dart' show SaropaContext;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String tempRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('saropa_lints_tool_skip_');
    tempRoot = tempDir.path;
    // Minimal pubspec.yaml so findProjectRoot can locate the package root.
    // Without this the helper bails out early returning false, which would
    // mask a real regression.
    File(
      p.join(tempRoot, 'pubspec.yaml'),
    ).writeAsStringSync('name: tool_skip_fixture\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('SaropaContext.isPathUnderProjectTool', () {
    test('returns true for files directly under <projectRoot>/tool/', () {
      final path = p.join(tempRoot, 'tool', 'audit.dart');
      expect(SaropaContext.isPathUnderProjectTool(path), isTrue);
    });

    test('returns true for files nested deeper under tool/', () {
      // Some packages organize tool helpers in subdirectories
      // (e.g. tool/codegen/foo.dart). The skip should still apply.
      final path = p.join(tempRoot, 'tool', 'codegen', 'foo.dart');
      expect(SaropaContext.isPathUnderProjectTool(path), isTrue);
    });

    test('returns false for files under lib/', () {
      final path = p.join(tempRoot, 'lib', 'src', 'thing.dart');
      expect(SaropaContext.isPathUnderProjectTool(path), isFalse);
    });

    test('returns false for files under bin/', () {
      // bin/ has its own dedicated skip; tool/ predicate must not also
      // claim bin/, or the two skips would duplicate work and the
      // intent of each predicate would be muddled.
      final path = p.join(tempRoot, 'bin', 'cli.dart');
      expect(SaropaContext.isPathUnderProjectTool(path), isFalse);
    });

    test('returns false when path empty', () {
      expect(SaropaContext.isPathUnderProjectTool(''), isFalse);
    });

    test('does not match prefix-only directories like tooling/', () {
      // Guard against the naive `contains("/tool")` substring approach,
      // which would also match `lib/tooling/foo.dart`. The implementation
      // anchors on the trailing slash (`<root>/tool/`) so this stays false.
      final path = p.join(tempRoot, 'lib', 'tooling', 'thing.dart');
      expect(SaropaContext.isPathUnderProjectTool(path), isFalse);
    });

    test('handles Windows backslash separators', () {
      // The analyzer surfaces paths in the platform's native form. On
      // Windows that is backslash-separated, so the helper must normalize
      // before comparing. Build the path explicitly with backslashes
      // (instead of `p.join`, which uses native separators) to exercise
      // this branch on every platform.
      final winPath = '$tempRoot\\tool\\audit.dart';
      expect(SaropaContext.isPathUnderProjectTool(winPath), isTrue);
    });

    test('returns false when no enclosing pubspec.yaml', () {
      // If findProjectRoot can't locate a project root the predicate
      // must return false rather than guessing — analyzer plugin paths
      // outside any package shouldn't be silently treated as tool
      // scripts.
      final orphanDir = Directory.systemTemp.createTempSync(
        'saropa_lints_tool_orphan_',
      );
      try {
        final path = p.join(orphanDir.path, 'tool', 'audit.dart');
        expect(SaropaContext.isPathUnderProjectTool(path), isFalse);
      } finally {
        orphanDir.deleteSync(recursive: true);
      }
    });
  });
}

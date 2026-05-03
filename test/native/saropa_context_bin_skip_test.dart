// Tests for SaropaContext.isPathUnderProjectBin — the universal `bin/`
// skip that prevents every saropa rule from firing on CLI executables.
//
// Why this lives at the SaropaContext layer rather than per-rule:
// many rules already gate on `isFlutterProject`, but the analyzer-plugin
// worker-isolate pool occasionally serves stale `_projectCache` entries
// that bypass the gate (manifests as 75+ `avoid_print_in_release` errors
// firing on bin/baseline.dart in non-Flutter projects). Centralising
// the skip means the noise is dropped uniformly regardless of the
// per-rule guard's cache state.
//
// The function under test is a pure path predicate. It resolves the
// project root by walking up to the nearest pubspec.yaml — same logic
// the rest of ProjectContext uses — and verifies the file lives at
// `<projectRoot>/bin/...`.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/native/saropa_context.dart'
    show SaropaContext;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String tempRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('saropa_lints_bin_skip_');
    tempRoot = tempDir.path;
    // Minimal pubspec.yaml so findProjectRoot can locate the package root.
    // Without this the helper bails out early returning false, which would
    // mask a real regression — every test below would pass for the wrong
    // reason.
    File(p.join(tempRoot, 'pubspec.yaml')).writeAsStringSync('name: bin_skip_fixture\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('SaropaContext.isPathUnderProjectBin', () {
    test('returns true for files directly under <projectRoot>/bin/', () {
      final path = p.join(tempRoot, 'bin', 'cli.dart');
      expect(SaropaContext.isPathUnderProjectBin(path), isTrue);
    });

    test('returns true for files nested deeper under bin/', () {
      // Some packages organise CLI helpers in subdirectories under bin/.
      // The skip should still apply — the directory is still part of the
      // CLI executables surface.
      final path = p.join(tempRoot, 'bin', 'tools', 'helper.dart');
      expect(SaropaContext.isPathUnderProjectBin(path), isTrue);
    });

    test('returns false for files under lib/', () {
      final path = p.join(tempRoot, 'lib', 'src', 'thing.dart');
      expect(SaropaContext.isPathUnderProjectBin(path), isFalse);
    });

    test('returns false for files under test/', () {
      final path = p.join(tempRoot, 'test', 'thing_test.dart');
      expect(SaropaContext.isPathUnderProjectBin(path), isFalse);
    });

    test('returns false when path empty', () {
      expect(SaropaContext.isPathUnderProjectBin(''), isFalse);
    });

    test('does not match prefix-only directories like binary/', () {
      // Guard against the naive `contains("/bin")` substring approach,
      // which would also match `lib/binary/foo.dart`. The implementation
      // anchors on the trailing slash (`<root>/bin/`) so this stays false.
      final path = p.join(tempRoot, 'lib', 'binary', 'thing.dart');
      expect(SaropaContext.isPathUnderProjectBin(path), isFalse);
    });

    test('handles Windows backslash separators', () {
      // The analyzer surfaces paths in the platform's native form. On
      // Windows that is backslash-separated, so the helper must normalise
      // before comparing. Build the path explicitly with backslashes
      // (instead of `p.join`, which uses native separators) to exercise
      // this branch on every platform.
      final winPath = '$tempRoot\\bin\\cli.dart';
      expect(SaropaContext.isPathUnderProjectBin(winPath), isTrue);
    });

    test('returns false when no enclosing pubspec.yaml', () {
      // If findProjectRoot can't locate a project root the predicate
      // must return false rather than guessing — analyzer plugin paths
      // outside any package (rare, but possible during boot or for
      // virtual files) shouldn't be silently treated as CLI scripts.
      final orphanDir = Directory.systemTemp.createTempSync(
        'saropa_lints_bin_orphan_',
      );
      try {
        final path = p.join(orphanDir.path, 'bin', 'cli.dart');
        expect(SaropaContext.isPathUnderProjectBin(path), isFalse);
      } finally {
        orphanDir.deleteSync(recursive: true);
      }
    });
  });
}

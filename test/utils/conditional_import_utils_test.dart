/// Unit tests for [isNativeOnlyConditionalImportTarget].
///
/// Verifies that only the native branch of `dart.library.io` / `dart.library.ffi`
/// conditional imports is classified as native-only, using isolated temp packages so
/// [findProjectRoot] does not resolve to the saropa_lints monorepo.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/conditional_import_utils.dart';
import 'package:test/test.dart';

void main() {
  group('isNativeOnlyConditionalImportTarget', () {
    test('returns false for null or empty path', () {
      expect(isNativeOnlyConditionalImportTarget(null), isFalse);
      expect(isNativeOnlyConditionalImportTarget(''), isFalse);
    });

    test(
      'returns false when file is not a native conditional target (isolated package)',
      () {
        final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
        try {
          // Publish runs tests with TMP under the repo; without a pubspec here,
          // findProjectRoot would walk up to saropa_lints. A local pubspec keeps
          // the nearest root this temp package so we only scan its empty lib/.
          File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: isolated_cond_import_probe
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
          final libDir = Directory(p.join(dir.path, 'lib'));
          libDir.createSync(recursive: true);
          final filePath = p.join(libDir.path, 'some.dart');
          File(filePath).writeAsStringSync('void main() {}');
          expect(isNativeOnlyConditionalImportTarget(filePath), isFalse);
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'returns true when file is dart.library.io conditional import target',
      () {
        final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
        try {
          _createTempProject(
            dir.path,
            importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
          );
          final nativePath = p.join(dir.path, 'lib', 'native_impl.dart');
          expect(isNativeOnlyConditionalImportTarget(nativePath), isTrue);
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'returns true when file is dart.library.ffi conditional import target',
      () {
        final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
        try {
          _createTempProject(
            dir.path,
            importerContent: '''
import 'executor_web.dart' if (dart.library.ffi) 'executor_native.dart';
''',
          );
          final nativePath = p.join(dir.path, 'lib', 'executor_native.dart');
          File(nativePath).writeAsStringSync('void f() {}');
          expect(isNativeOnlyConditionalImportTarget(nativePath), isTrue);
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );

    test('returns false for stub file (default branch)', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(
          dir.path,
          importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
        );
        final stubPath = p.join(dir.path, 'lib', 'stub.dart');
        expect(isNativeOnlyConditionalImportTarget(stubPath), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns false for file in lib that is not a conditional target', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(
          dir.path,
          importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
        );
        final otherPath = p.join(dir.path, 'lib', 'other.dart');
        File(otherPath).writeAsStringSync('void other() {}');
        expect(isNativeOnlyConditionalImportTarget(otherPath), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test(
      'returns true when target is referenced via package URI (same package)',
      () {
        final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
        try {
          _createTempProject(
            dir.path,
            importerContent: '''
import 'package:test_package/stub.dart' if (dart.library.io) 'package:test_package/native_impl.dart';
''',
          );
          final nativePath = p.join(dir.path, 'lib', 'native_impl.dart');
          expect(isNativeOnlyConditionalImportTarget(nativePath), isTrue);
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );

    // Hypothesis B from the bug report: a conditional `export` is just as much
    // a native-only branch as a conditional `import`. The scanner must collect
    // from ExportDirective configurations too, not only ImportDirective.
    test(
      'returns true when file is dart.library.io conditional EXPORT target',
      () {
        final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
        try {
          _createTempProject(
            dir.path,
            importerContent: '''
export 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
          );
          final nativePath = p.join(dir.path, 'lib', 'native_impl.dart');
          expect(isNativeOnlyConditionalImportTarget(nativePath), isTrue);
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );

    // Option (c) naming heuristic: a `*_io.dart` with a sibling `*_stub.dart`
    // is native-only by convention even when no directive we parsed wires them.
    test('returns true for *_io.dart with a sibling *_stub.dart', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        final libDir = Directory(p.join(dir.path, 'lib'))
          ..createSync(recursive: true);
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
        final ioPath = p.join(libDir.path, 'server_io.dart');
        File(ioPath).writeAsStringSync('void serve() {}');
        File(
          p.join(libDir.path, 'server_stub.dart'),
        ).writeAsStringSync('void serve() {}');
        expect(isNativeOnlyConditionalImportTarget(ioPath), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns false for *_io.dart with no sibling *_stub.dart', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        final libDir = Directory(p.join(dir.path, 'lib'))
          ..createSync(recursive: true);
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
        final ioPath = p.join(libDir.path, 'server_io.dart');
        File(ioPath).writeAsStringSync('void serve() {}');
        expect(isNativeOnlyConditionalImportTarget(ioPath), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    // Case 5 from the bug report: a file referenced by BOTH a conditional io
    // branch AND an unconditional import can still load on web, so it must NOT
    // be suppressed (the kIsWeb guard is genuinely required there).
    test('returns false when target is also imported unconditionally', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(
          dir.path,
          importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
        );
        // A second file pulls native_impl.dart in unconditionally — this is
        // the path that can reach it on web.
        File(p.join(dir.path, 'lib', 'plain_importer.dart')).writeAsStringSync(
          '''
import 'native_impl.dart';
''',
        );
        final nativePath = p.join(dir.path, 'lib', 'native_impl.dart');
        expect(isNativeOnlyConditionalImportTarget(nativePath), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}

/// Writes `pubspec.yaml`, stub/native impl files, and [importerContent] under [projectRoot]/lib.
void _createTempProject(String projectRoot, {required String importerContent}) {
  final libDir = Directory(p.join(projectRoot, 'lib'));
  libDir.createSync(recursive: true);
  File(p.join(projectRoot, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
  File(p.join(libDir.path, 'stub.dart')).writeAsStringSync('void stub() {}');
  File(
    p.join(libDir.path, 'native_impl.dart'),
  ).writeAsStringSync('void nativeImpl() {}');
  File(p.join(libDir.path, 'importer.dart')).writeAsStringSync(importerContent);
}

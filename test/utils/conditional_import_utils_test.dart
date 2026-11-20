/// Unit tests for [isNativeOnlyConditionalImportTarget].
///
/// Verifies that only the native branch of `dart.library.io` / `dart.library.ffi`
/// conditional imports is classified as native-only, using isolated temp packages so
/// [findProjectRoot] does not resolve to the saropa_lints monorepo.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/conditional_import_utils.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

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
          // Retry-tolerant cleanup: Windows file handles can linger after tests
          safeDeleteDir(dir);
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
          safeDeleteDir(dir);
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
          safeDeleteDir(dir);
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
        safeDeleteDir(dir);
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
        safeDeleteDir(dir);
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
          safeDeleteDir(dir);
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
          safeDeleteDir(dir);
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
        safeDeleteDir(dir);
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
        safeDeleteDir(dir);
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
        safeDeleteDir(dir);
      }
    });
  });

  // See bugs/function_always_returns_null_false_positive_conditional_import_
  // web_stub.dart: FunctionAlwaysReturnsNullRule uses
  // isConditionalImportStubTarget to skip the web/stub half of a
  // dart.library.io conditional import, since a stub member that always
  // returns null is honoring its contract, not exhibiting a code smell.
  group('isConditionalImportStubTarget', () {
    test('returns false for null or empty path', () {
      expect(isConditionalImportStubTarget(null), isFalse);
      expect(isConditionalImportStubTarget(''), isFalse);
    });

    test(
      'returns true for the default branch of a dart.library.io conditional import',
      () {
        final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
        try {
          _createTempProject(
            dir.path,
            importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
          );
          final stubPath = p.join(dir.path, 'lib', 'stub.dart');
          expect(isConditionalImportStubTarget(stubPath), isTrue);
        } finally {
          safeDeleteDir(dir);
        }
      },
    );

    test(
      'returns true for the default branch of a dart.library.ffi conditional export',
      () {
        final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
        try {
          _createTempProject(
            dir.path,
            importerContent: '''
export 'stub.dart' if (dart.library.ffi) 'native_impl.dart';
''',
          );
          final stubPath = p.join(dir.path, 'lib', 'stub.dart');
          expect(isConditionalImportStubTarget(stubPath), isTrue);
        } finally {
          safeDeleteDir(dir);
        }
      },
    );

    test('returns false for the native branch itself', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(
          dir.path,
          importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
        );
        final nativePath = p.join(dir.path, 'lib', 'native_impl.dart');
        expect(isConditionalImportStubTarget(nativePath), isFalse);
      } finally {
        safeDeleteDir(dir);
      }
    });

    test('returns false for a file with no conditional import wiring', () {
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
        expect(isConditionalImportStubTarget(otherPath), isFalse);
      } finally {
        safeDeleteDir(dir);
      }
    });

    // Naming-convention fallback (mirrors _collectSiblingStubTarget): a
    // `*_stub.dart` file with a sibling `*_io.dart` is the web branch of the
    // standard split even when no directive we parsed wires them together.
    // This is the exact shape from the bug report's
    // `drift_debug_server_stub.dart` / `drift_debug_server_io.dart` pair.
    test('returns true for *_stub.dart with a sibling *_io.dart', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        final libDir = Directory(p.join(dir.path, 'lib'))
          ..createSync(recursive: true);
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
        final stubPath = p.join(libDir.path, 'drift_debug_server_stub.dart');
        File(stubPath).writeAsStringSync('''
class DriftDebugServer {
  static int? get port => null;
}
''');
        File(
          p.join(libDir.path, 'drift_debug_server_io.dart'),
        ).writeAsStringSync('''
class DriftDebugServer {
  static int? get port => 1234;
}
''');
        expect(isConditionalImportStubTarget(stubPath), isTrue);
      } finally {
        safeDeleteDir(dir);
      }
    });

    test('returns false for *_stub.dart with no sibling *_io.dart', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        final libDir = Directory(p.join(dir.path, 'lib'))
          ..createSync(recursive: true);
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
        final stubPath = p.join(libDir.path, 'lonely_stub.dart');
        File(stubPath).writeAsStringSync('void serve() {}');
        expect(isConditionalImportStubTarget(stubPath), isFalse);
      } finally {
        safeDeleteDir(dir);
      }
    });
  });

  // See bugs/avoid_platform_specific_imports_false_positive_io_only_subtree_of_
  // conditional_export.md: files imported only by the dart.library.io branch
  // are never compiled for web, so avoid_platform_specific_imports must skip
  // them; files also reachable from the stub/web path must still be flagged.
  group('isInNativeOnlyImportClosure', () {
    test('returns false for null or empty path', () {
      expect(isInNativeOnlyImportClosure(null), isFalse);
      expect(isInNativeOnlyImportClosure(''), isFalse);
    });

    test('FP case: file imported only by the io target is in the closure', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(
          dir.path,
          importerContent: '''
export 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
        );
        final libDir = p.join(dir.path, 'lib');
        // native_impl.dart pulls in server/auth_handler.dart, which in turn
        // pulls in server/deep.dart: a two-level io-only subtree.
        File(p.join(libDir, 'native_impl.dart')).writeAsStringSync('''
import 'server/auth_handler.dart';
''');
        Directory(p.join(libDir, 'server')).createSync();
        File(p.join(libDir, 'server', 'auth_handler.dart')).writeAsStringSync(
          '''
import 'dart:io';
import 'deep.dart';
''',
        );
        File(
          p.join(libDir, 'server', 'deep.dart'),
        ).writeAsStringSync("import 'dart:io';\n");
        expect(
          isInNativeOnlyImportClosure(
            p.join(libDir, 'server', 'auth_handler.dart'),
          ),
          isTrue,
        );
        expect(
          isInNativeOnlyImportClosure(p.join(libDir, 'server', 'deep.dart')),
          isTrue,
        );
      } finally {
        safeDeleteDir(dir);
      }
    });

    // Positive case: the rule must still fire for web-reachable files.
    test('file also imported from the stub/web path is NOT in the closure', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(
          dir.path,
          importerContent: '''
export 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
        );
        final libDir = p.join(dir.path, 'lib');
        File(p.join(libDir, 'native_impl.dart')).writeAsStringSync('''
import 'shared.dart';
''');
        // The stub (web) branch also imports shared.dart, so web can load it.
        File(p.join(libDir, 'stub.dart')).writeAsStringSync('''
import 'shared.dart';
''');
        File(p.join(libDir, 'shared.dart')).writeAsStringSync(
          "import 'dart:io';\n",
        );
        expect(
          isInNativeOnlyImportClosure(p.join(libDir, 'shared.dart')),
          isFalse,
        );
      } finally {
        safeDeleteDir(dir);
      }
    });

    test('file with no importers (possible entry point) is NOT in closure', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(
          dir.path,
          importerContent: '''
export 'stub.dart' if (dart.library.io) 'native_impl.dart';
''',
        );
        final orphan = p.join(dir.path, 'lib', 'orphan.dart');
        File(orphan).writeAsStringSync("import 'dart:io';\n");
        expect(isInNativeOnlyImportClosure(orphan), isFalse);
      } finally {
        safeDeleteDir(dir);
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
